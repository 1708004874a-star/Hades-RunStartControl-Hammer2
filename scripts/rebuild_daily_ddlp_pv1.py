#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rebuild_daily_ddlp_pv1.py
=========================

把原本的一段 PostgreSQL 脚本封装成可以在终端运行的 Python 程序，用来重建 /
刷新 ``dlp04.daily_ddlp_pv1`` 这张表。

脚本依次执行下面几个步骤（每一步都可以单独跳过）：

  1. (可选) TRUNCATE 清空表          —— --truncate
  2. 删除并重建唯一索引               —— 默认执行，可用 --skip-index 跳过
  3. upsert 生产数据(PV/QTY/UT)       —— 默认执行，取 tsdate >= --since(默认 2026-01-01)
  4. 用停机数据回填 ot 字段           —— 默认执行
  5. (可选) 打印校验查询结果          —— --verify

说明：第 3 步是 ON CONFLICT(plant_id, day, line_id) 的 upsert，所以“从某天起
全量重建”和“日常刷新”是同一条语句——已存在的键更新、不存在的插入，重复运行
幂等、不会产生重复行。要彻底删库重跑就加 --truncate。

数据库连接信息从标准的 PG* 环境变量读取（PGHOST / PGPORT / PGDATABASE /
PGUSER / PGPASSWORD），也可以用命令行参数覆盖，或直接用 --dsn 传一个完整的
连接串。

依赖:
    pip install "psycopg[binary]"        # psycopg 3 (推荐)
    # 或者
    pip install psycopg2-binary          # psycopg 2

用法示例:
    # 用环境变量里的连接信息，跑完整流程
    export PGHOST=localhost PGDATABASE=mydb PGUSER=me PGPASSWORD=secret
    python scripts/rebuild_daily_ddlp_pv1.py

    # 删库重跑：先清空，再从 2026-01-01 起全量重建，结束后打印校验结果
    python scripts/rebuild_daily_ddlp_pv1.py --truncate --since 2026-01-01 --verify

    # 只看会执行什么，不真正写库
    python scripts/rebuild_daily_ddlp_pv1.py --dry-run

    # 直接给完整连接串
    python scripts/rebuild_daily_ddlp_pv1.py --dsn "postgresql://me:secret@host:5432/mydb"
"""

from __future__ import annotations

import argparse
import os
import sys
import textwrap


# --------------------------------------------------------------------------- #
#  数据库驱动: 优先用 psycopg(3)，没有就退回 psycopg2
# --------------------------------------------------------------------------- #
def _import_driver():
    try:
        import psycopg  # type: ignore

        return "psycopg3", psycopg
    except ImportError:
        pass
    try:
        import psycopg2  # type: ignore

        return "psycopg2", psycopg2
    except ImportError:
        sys.exit(
            "找不到 PostgreSQL 驱动。请先安装：\n"
            "    pip install 'psycopg[binary]'   # 推荐 (psycopg 3)\n"
            "  或\n"
            "    pip install psycopg2-binary"
        )


# --------------------------------------------------------------------------- #
#  SQL 语句 —— 与原始脚本保持一致（用 raw 字符串保留正则里的反斜杠）
# --------------------------------------------------------------------------- #

SQL_TRUNCATE = "TRUNCATE TABLE dlp04.daily_ddlp_pv1;"

# 删除可能存在的同名 / 历史索引，然后重建唯一索引
SQL_REBUILD_INDEX = r"""
DROP INDEX IF EXISTS idx_pv1_plant_day_line;
DROP INDEX IF EXISTS dlp04.idx_pv1_plant_daily_line;
DROP INDEX IF EXISTS idx_pv_plant_daily_line;
DROP INDEX IF EXISTS dlp04.idx_pv1_plant_day_line;

CREATE UNIQUE INDEX idx_pv1_plant_day_line
    ON dlp04.daily_ddlp_pv1 (plant_id, day, line_id);
"""

# 增量 upsert：从 public.lds_production_data 汇总，写入 dlp04.daily_ddlp_pv1
# 取 tsdate >= :since（默认 2026-01-01）到今天（不含今天）的数据。
# 因为有 ON CONFLICT(plant_id, day, line_id)，这一条同时是“全量重建”和“日常刷新”：
# 已存在的键更新、不存在的插入，重复运行幂等、不会产生重复行。
SQL_UPSERT = r"""
INSERT INTO dlp04.daily_ddlp_pv1 (
    plant_id,
    plant_name,
    daily,               -- 改为存日数字
    year,
    month,
    day,                 -- 完整日期
    ut,
    qty,
    line_id,
    line_name,
    create_time,
    update_time
)
SELECT
    166 AS plant_id,
    'SSPA' AS plant_name,
    EXTRACT(DAY FROM t.tsdate)::int AS daily,
    CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 10000 AS year,
    (CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 100) %% 100 AS month,
    t.tsdate::date AS day,
    t.line_ut,
    t.line_qty,
    t.line_id,
    t.line_name,
    now() AS create_time,
    now() AS update_time
FROM (
    WITH t1 AS (
        SELECT
            substring(line_name FROM '.*\\.*\\(.*$)') AS line,
            tsdate,
            goodparts,
            repairedparts,
            badparts,
            productid,
            ut,
            lineid
        FROM public.lds_production_data
        WHERE tsdate >= %(since)s
          AND tsdate <  current_date
    ),
    t2 AS (
        SELECT
            concat(line, TRIM(productid)) AS line_product,
            tsdate,
            goodparts,
            repairedparts,
            badparts,
            line,
            ut,
            productid,
            lineid
        FROM t1
    ),
    t3 AS (
        SELECT
            t2.tsdate,
            t2.line_product,
            t2.goodparts,
            t2.repairedparts,
            t2.badparts,
            t2.line,
            t2.lineid,
            reference_unit.ut AS reference_ut,
            t2.ut,
            t2.productid,
            reference_unit.ut AS per_ut
        FROM t2
        LEFT JOIN public.reference_unit
            ON t2.line_product = reference_unit.line_product
        WHERE t2.tsdate IS NOT NULL
    ),
    t4 AS (
        SELECT
            t3.tsdate,
            t3.lineid AS line_id,
            t3.ut,
            rel.name AS line_name,
            (t3.goodparts + t3.repairedparts) * t3.per_ut AS line_ut,
            (t3.goodparts + t3.repairedparts + COALESCE(t3.badparts, 0)) AS line_qty
        FROM t3
        INNER JOIN dlp_uoc.dlp_datasource_relation rel
            ON t3.line = rel.def
    ),
    t5 AS (
        SELECT
            t4.tsdate,
            t4.line_id,
            t4.line_name,
            SUM(COALESCE(t4.line_ut, t4.ut)) / 60 AS line_ut,
            SUM(t4.line_qty) AS line_qty
        FROM t4
        GROUP BY t4.tsdate, t4.line_id, t4.line_name
    )
    SELECT * FROM t5
) t
ON CONFLICT (plant_id, day, line_id)
DO UPDATE SET
    ut          = EXCLUDED.ut,
    qty         = EXCLUDED.qty,
    line_name   = EXCLUDED.line_name,
    daily       = EXCLUDED.daily,
    update_time = now();
"""

# 回填 ot 字段：用 lds_production_time（操作时间）减去 dlp.red_time 里 T4 类停机时间
SQL_UPDATE_OT = r"""
UPDATE dlp04.daily_ddlp_pv1 AS pv
SET ot = CASE
           WHEN src.red_downtime IS NULL THEN src.lds_ot / 60.0
           ELSE (src.lds_ot - src.red_downtime) / 60.0
         END
FROM (
    SELECT
        t2.shift_date AS tsdate,
        t2.line_name,
        t2.line_ot * 60.0 AS lds_ot,
        t3.red_time * 60.0 AS red_downtime
    FROM (
        SELECT
            t1.shift_date,
            dlp_datasource_relation.name AS line_name,
            SUM(t1.ot) / 60.0 AS line_ot
        FROM (
            SELECT
                SUBSTRING(line_name FROM '.*\\.*\\(.*$)') AS l_name,
                *
            FROM public.lds_production_time
            WHERE to_char(date_trunc('month', shift_date), 'YYYY-MM-DD') > '2025-12-31'
        ) t1
        LEFT JOIN dlp_uoc.dlp_datasource_relation
            ON t1.l_name = dlp_datasource_relation.def
        GROUP BY t1.shift_date, dlp_datasource_relation.name
    ) t2
    LEFT JOIN (
        SELECT
            tsdate,
            line,
            SUM(downtime) / 60.0 AS red_time
        FROM dlp.red_time
        WHERE substr(reason, 1, 2) = 'T4'
        GROUP BY tsdate, line
    ) t3
        ON t2.line_name = t3.line
       AND t2.shift_date = t3.tsdate
) AS src
WHERE pv.day = src.tsdate
  AND pv.line_name = src.line_name;
"""

# 校验用查询（只读，--verify 时执行并打印）
SQL_VERIFY = r"""
SELECT
    id,
    day,
    line_id,
    line_name,
    ut,
    qty,
    ot,
    update_time
FROM dlp04.daily_ddlp_pv1
WHERE day >= current_date - interval '10 days'
ORDER BY day DESC, line_id;
"""


# --------------------------------------------------------------------------- #
#  执行逻辑
# --------------------------------------------------------------------------- #
def run_statement(cur, label, sql, params=None, dry_run=False):
    """执行一条/一组语句，打印受影响行数。"""
    print(f"\n>>> {label}")
    if dry_run:
        print(textwrap.indent(sql.strip(), "    "))
        print("    [dry-run] 未真正执行")
        return
    cur.execute(sql, params or {})
    # executemany/多语句时 rowcount 是最后一条的，仅供参考
    rc = cur.rowcount
    if rc is not None and rc >= 0:
        print(f"    完成，受影响行数: {rc}")
    else:
        print("    完成")


def run_verify(cur):
    print("\n>>> 校验：最近 10 天数据 (按 day 倒序)")
    cur.execute(SQL_VERIFY)
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description]
    print("    " + " | ".join(cols))
    print("    " + "-" * 60)
    for row in rows[:50]:  # 最多打印 50 行，避免刷屏
        print("    " + " | ".join("" if v is None else str(v) for v in row))
    print(f"    共 {len(rows)} 行" + (" (仅显示前 50 行)" if len(rows) > 50 else ""))


def build_conn_kwargs(args):
    """优先用 --dsn；否则用命令行参数 / 环境变量。"""
    if args.dsn:
        return {"dsn_or_conninfo": args.dsn}
    kwargs = {}
    # 命令行参数优先，其次环境变量，最后默认值
    host = args.host or os.getenv("PGHOST", "localhost")
    port = args.port or os.getenv("PGPORT", "5432")
    dbname = args.dbname or os.getenv("PGDATABASE")
    user = args.user or os.getenv("PGUSER")
    password = args.password or os.getenv("PGPASSWORD")
    if not dbname or not user:
        sys.exit(
            "缺少数据库名或用户名。请通过 --dbname/--user 或环境变量 "
            "PGDATABASE/PGUSER 提供，或者直接用 --dsn。"
        )
    kwargs.update(
        host=host, port=port, dbname=dbname, user=user
    )
    if password is not None:
        kwargs["password"] = password
    return kwargs


def connect(driver_name, driver, conn_kwargs):
    if "dsn_or_conninfo" in conn_kwargs:
        dsn = conn_kwargs["dsn_or_conninfo"]
        return driver.connect(dsn)
    return driver.connect(**conn_kwargs)


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        description="重建 / 刷新 dlp04.daily_ddlp_pv1 表",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    # 连接参数
    p.add_argument("--dsn", help="完整连接串，如 postgresql://user:pwd@host:5432/db")
    p.add_argument("--host", help="数据库主机 (默认 $PGHOST 或 localhost)")
    p.add_argument("--port", help="端口 (默认 $PGPORT 或 5432)")
    p.add_argument("--dbname", help="数据库名 (默认 $PGDATABASE)")
    p.add_argument("--user", help="用户名 (默认 $PGUSER)")
    p.add_argument("--password", help="密码 (默认 $PGPASSWORD)")

    # 步骤开关
    p.add_argument("--truncate", action="store_true",
                   help="先 TRUNCATE 清空表（慎用，不可回滚）")
    p.add_argument("--skip-index", action="store_true",
                   help="跳过删除/重建唯一索引")
    p.add_argument("--skip-upsert", action="store_true",
                   help="跳过增量 upsert")
    p.add_argument("--skip-ot", action="store_true",
                   help="跳过 ot 字段回填")
    p.add_argument("--since", default="2026-01-01",
                   help="upsert 取 tsdate >= 该日期的数据 (默认 2026-01-01)")
    p.add_argument("--verify", action="store_true",
                   help="结束后打印最近 10 天的校验查询")
    p.add_argument("--dry-run", action="store_true",
                   help="只打印将执行的 SQL，不实际写库")
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    # dry-run 不需要驱动，也不需要真连库
    if args.dry_run:
        print("=== DRY RUN：以下语句不会真正执行 ===")

        class _FakeCur:
            description = []
            rowcount = -1
            def execute(self, *a, **k): pass
            def fetchall(self): return []

        _do_steps(_FakeCur(), args)
        print("\nDRY RUN 结束。")
        return 0

    driver_name, driver = _import_driver()
    conn_kwargs = build_conn_kwargs(args)
    print(f"使用驱动: {driver_name}")
    conn = connect(driver_name, driver, conn_kwargs)
    try:
        # 关闭自动提交，把 DDL + DML 放进一个事务里（TRUNCATE 除外的部分可回滚）
        conn.autocommit = False
        cur = conn.cursor()
        _do_steps(cur, args)
        conn.commit()
        print("\n✓ 全部完成，事务已提交。")
        if args.verify:
            run_verify(cur)
    except Exception as exc:
        conn.rollback()
        print(f"\n✗ 出错，已回滚事务：{exc}", file=sys.stderr)
        return 1
    finally:
        conn.close()
    return 0


def _do_steps(cur, args):
    if args.truncate:
        run_statement(cur, "步骤 1: TRUNCATE 清空表", SQL_TRUNCATE,
                      dry_run=args.dry_run)
    else:
        print("\n(跳过 TRUNCATE，未指定 --truncate)")

    if not args.skip_index:
        run_statement(cur, "步骤 2: 删除并重建唯一索引", SQL_REBUILD_INDEX,
                      dry_run=args.dry_run)

    if not args.skip_upsert:
        run_statement(cur, f"步骤 3: upsert (tsdate >= {args.since})",
                      SQL_UPSERT, params={"since": args.since},
                      dry_run=args.dry_run)

    if not args.skip_ot:
        run_statement(cur, "步骤 4: 回填 ot 字段", SQL_UPDATE_OT,
                      dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())

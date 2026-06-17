#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rebuild_daily_ddlp_pv2.py
=========================

“对照表”脚本：和 rebuild_daily_ddlp_pv1.sql 做完全相同的删库重建逻辑，
但写到一张**新表 dlp04.daily_ddlp_pv2**（结构照搬 pv1）。

用途：你用 SQL 在 DBeaver 里重建 pv1，再用这个 Python 脚本重建 pv2，
然后对比 pv1 / pv2 是否一致，用来验证脚本逻辑对不对。

步骤（每次跑都是完整的删库重建，安全可重复）：
  0. CREATE TABLE IF NOT EXISTS pv2  —— 结构照搬 pv1（首次自动建表）
  1. TRUNCATE pv2                    —— 清空
  2. 重建 pv2 的唯一索引             —— ON CONFLICT 的前提
  3. 【第一段 INSERT：纯插入】2026-01-01 至今全部数据（无 ON CONFLICT）
  4. 【第二段 INSERT：upsert】最近 50 天（ON CONFLICT DO UPDATE）
  5. 回填 ot
  6. (--verify) 打印 pv2 最近 10 天
  7. (--compare) 对比 pv1 vs pv2 的总量

连接信息：标准 PG* 环境变量 / 命令行参数 / --dsn，与 pv1 脚本一致。

依赖：
    pip install "psycopg[binary]"     # psycopg 3（推荐）
    # 或 pip install psycopg2-binary

用法示例：
    # 删库重建 pv2，并和 pv1 对比
    python scripts/rebuild_daily_ddlp_pv2.py --dsn "postgresql://用户名:密码@10.177.34.32:5432/unified_data" --verify --compare

    # 只看会执行什么，不写库
    python scripts/rebuild_daily_ddlp_pv2.py --dry-run
"""

from __future__ import annotations

import argparse
import os
import sys
import textwrap


# --------------------------------------------------------------------------- #
#  数据库驱动：优先 psycopg(3)，否则退回 psycopg2
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
#  SQL —— 全部针对 dlp04.daily_ddlp_pv2
# --------------------------------------------------------------------------- #

# 0. 首次自动建表：结构照搬 pv1（带上默认值和自增 id，但不抄索引，索引下面自己建）
SQL_CREATE_TABLE = r"""
CREATE TABLE IF NOT EXISTS dlp04.daily_ddlp_pv2
    (LIKE dlp04.daily_ddlp_pv1 INCLUDING DEFAULTS INCLUDING IDENTITY);
"""

# 1. 清空
SQL_TRUNCATE = "TRUNCATE TABLE dlp04.daily_ddlp_pv2;"

# 2. 重建唯一索引
SQL_REBUILD_INDEX = r"""
DROP INDEX IF EXISTS dlp04.idx_pv2_plant_day_line;
CREATE UNIQUE INDEX idx_pv2_plant_day_line
    ON dlp04.daily_ddlp_pv2 (plant_id, day, line_id);
"""

# 3. 第一段 INSERT：纯插入，2026-01-01 至今（无 ON CONFLICT），跑在刚清空的表上
SQL_INSERT_FULL = r"""
INSERT INTO dlp04.daily_ddlp_pv2 (
    plant_id, plant_name, daily, year, month, day,
    ut, qty, line_id, line_name, create_time, update_time
)
SELECT
    166 AS plant_id,
    'SSPA' AS plant_name,
    EXTRACT(DAY FROM t.tsdate)::int AS daily,
    CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 10000 AS year,
    (CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 100) %% 100 AS month,
    t.tsdate::date AS day,
    t.line_ut, t.line_qty, t.line_id, t.line_name,
    now() AS create_time, now() AS update_time
FROM (
    WITH t1 AS (
        SELECT
            substring(line_name FROM '.*\\.*\\(.*$)') AS line,
            tsdate, goodparts, repairedparts, badparts, productid, ut, lineid
        FROM public.lds_production_data
        WHERE tsdate >= %(since)s
          AND tsdate <  current_date
    ),
    t2 AS (
        SELECT concat(line, TRIM(productid)) AS line_product,
               tsdate, goodparts, repairedparts, badparts, line, ut, productid, lineid
        FROM t1
    ),
    t3 AS (
        SELECT
            t2.tsdate, t2.line_product, t2.goodparts, t2.repairedparts, t2.badparts,
            t2.line, t2.lineid, reference_unit.ut AS reference_ut, t2.ut, t2.productid,
            reference_unit.ut AS per_ut
        FROM t2
        LEFT JOIN public.reference_unit ON t2.line_product = reference_unit.line_product
        WHERE t2.tsdate IS NOT NULL
    ),
    t4 AS (
        SELECT
            t3.tsdate, t3.lineid AS line_id, t3.ut, rel.name AS line_name,
            (t3.goodparts + t3.repairedparts) * t3.per_ut AS line_ut,
            (t3.goodparts + t3.repairedparts + COALESCE(t3.badparts, 0)) AS line_qty
        FROM t3
        INNER JOIN dlp_uoc.dlp_datasource_relation rel ON t3.line = rel.def
    ),
    t5 AS (
        SELECT t4.tsdate, t4.line_id, t4.line_name,
               SUM(COALESCE(t4.line_ut, t4.ut)) / 60 AS line_ut,
               SUM(t4.line_qty) AS line_qty
        FROM t4
        GROUP BY t4.tsdate, t4.line_id, t4.line_name
    )
    SELECT * FROM t5
) t;
"""

# 4. 第二段 INSERT：upsert，最近 N 天（默认 50），靠唯一索引更新已有/插入新增
SQL_UPSERT_RECENT = r"""
INSERT INTO dlp04.daily_ddlp_pv2 (
    plant_id, plant_name, daily, year, month, day,
    ut, qty, line_id, line_name, create_time, update_time
)
SELECT
    166 AS plant_id,
    'SSPA' AS plant_name,
    EXTRACT(DAY FROM t.tsdate)::int AS daily,
    CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 10000 AS year,
    (CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 100) %% 100 AS month,
    t.tsdate::date AS day,
    t.line_ut, t.line_qty, t.line_id, t.line_name,
    now() AS create_time, now() AS update_time
FROM (
    WITH t1 AS (
        SELECT
            substring(line_name FROM '.*\\.*\\(.*$)') AS line,
            tsdate, goodparts, repairedparts, badparts, productid, ut, lineid
        FROM public.lds_production_data
        WHERE tsdate >= current_date - make_interval(days => %(days)s)
          AND tsdate <  current_date
    ),
    t2 AS (
        SELECT concat(line, TRIM(productid)) AS line_product,
               tsdate, goodparts, repairedparts, badparts, line, ut, productid, lineid
        FROM t1
    ),
    t3 AS (
        SELECT
            t2.tsdate, t2.line_product, t2.goodparts, t2.repairedparts, t2.badparts,
            t2.line, t2.lineid, reference_unit.ut AS reference_ut, t2.ut, t2.productid,
            reference_unit.ut AS per_ut
        FROM t2
        LEFT JOIN public.reference_unit ON t2.line_product = reference_unit.line_product
        WHERE t2.tsdate IS NOT NULL
    ),
    t4 AS (
        SELECT
            t3.tsdate, t3.lineid AS line_id, t3.ut, rel.name AS line_name,
            (t3.goodparts + t3.repairedparts) * t3.per_ut AS line_ut,
            (t3.goodparts + t3.repairedparts + COALESCE(t3.badparts, 0)) AS line_qty
        FROM t3
        INNER JOIN dlp_uoc.dlp_datasource_relation rel ON t3.line = rel.def
    ),
    t5 AS (
        SELECT t4.tsdate, t4.line_id, t4.line_name,
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

# 5. 回填 ot
SQL_UPDATE_OT = r"""
UPDATE dlp04.daily_ddlp_pv2 AS pv
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
            SELECT SUBSTRING(line_name FROM '.*\\.*\\(.*$)') AS l_name, *
            FROM public.lds_production_time
            WHERE shift_date >= %(since)s
        ) t1
        LEFT JOIN dlp_uoc.dlp_datasource_relation ON t1.l_name = dlp_datasource_relation.def
        GROUP BY t1.shift_date, dlp_datasource_relation.name
    ) t2
    LEFT JOIN (
        SELECT tsdate, line, SUM(downtime) / 60.0 AS red_time
        FROM dlp.red_time
        WHERE substr(reason, 1, 2) = 'T4'
        GROUP BY tsdate, line
    ) t3
        ON t2.line_name = t3.line AND t2.shift_date = t3.tsdate
) AS src
WHERE pv.day = src.tsdate
  AND pv.line_name = src.line_name;
"""

# 6. 校验：pv2 最近 10 天
SQL_VERIFY = r"""
SELECT id, day, plant_id, line_id, line_name, ut, qty, ot, update_time
FROM dlp04.daily_ddlp_pv2
WHERE day >= current_date - interval '10 days'
ORDER BY day DESC, line_id;
"""

# 7. 对比：pv1 vs pv2 的总量（行数 / qty 合计 / ut 合计）
SQL_COMPARE = r"""
SELECT 'pv1' AS tbl, count(*) AS rows,
       sum(qty) AS sum_qty, round(sum(ut)::numeric, 2) AS sum_ut
FROM dlp04.daily_ddlp_pv1
WHERE day >= %(since)s
UNION ALL
SELECT 'pv2', count(*),
       sum(qty), round(sum(ut)::numeric, 2)
FROM dlp04.daily_ddlp_pv2
WHERE day >= %(since)s;
"""


# --------------------------------------------------------------------------- #
#  执行
# --------------------------------------------------------------------------- #
def run_statement(cur, label, sql, params=None, dry_run=False):
    print(f"\n>>> {label}")
    if dry_run:
        print(textwrap.indent(sql.strip(), "    "))
        print("    [dry-run] 未真正执行")
        return
    cur.execute(sql, params or {})
    rc = cur.rowcount
    print(f"    完成" + (f"，受影响行数: {rc}" if rc is not None and rc >= 0 else ""))


def _print_rows(cur, limit=50):
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description]
    print("    " + " | ".join(cols))
    print("    " + "-" * 60)
    for row in rows[:limit]:
        print("    " + " | ".join("" if v is None else str(v) for v in row))
    print(f"    共 {len(rows)} 行" + (f" (仅显示前 {limit} 行)" if len(rows) > limit else ""))


def run_verify(cur):
    print("\n>>> 校验：pv2 最近 10 天 (按 day 倒序)")
    cur.execute(SQL_VERIFY)
    _print_rows(cur)


def run_compare(cur, since):
    print("\n>>> 对比：pv1 vs pv2 (day >= %s 的行数 / qty 合计 / ut 合计)" % since)
    cur.execute(SQL_COMPARE, {"since": since})
    _print_rows(cur)
    print("    两行数字一致 = Python 脚本和 SQL 结果一致 ✓")


def build_conn_kwargs(args):
    if args.dsn:
        return {"dsn_or_conninfo": args.dsn}
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
    kwargs = dict(host=host, port=port, dbname=dbname, user=user)
    if password is not None:
        kwargs["password"] = password
    return kwargs


def connect(driver, conn_kwargs):
    if "dsn_or_conninfo" in conn_kwargs:
        return driver.connect(conn_kwargs["dsn_or_conninfo"])
    return driver.connect(**conn_kwargs)


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        description="删库重建对照表 dlp04.daily_ddlp_pv2（结构照搬 pv1）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--dsn", help="完整连接串，如 postgresql://user:pwd@host:5432/db")
    p.add_argument("--host", help="数据库主机 (默认 $PGHOST 或 localhost)")
    p.add_argument("--port", help="端口 (默认 $PGPORT 或 5432)")
    p.add_argument("--dbname", help="数据库名 (默认 $PGDATABASE)")
    p.add_argument("--user", help="用户名 (默认 $PGUSER)")
    p.add_argument("--password", help="密码 (默认 $PGPASSWORD)")

    p.add_argument("--since", default="2026-01-01",
                   help="第一段纯插入取 tsdate >= 该日期 (默认 2026-01-01)")
    p.add_argument("--days", type=int, default=50,
                   help="第二段 upsert 取最近多少天 (默认 50)")
    p.add_argument("--verify", action="store_true", help="结束后打印 pv2 最近 10 天")
    p.add_argument("--compare", action="store_true", help="结束后对比 pv1 vs pv2 总量")
    p.add_argument("--dry-run", action="store_true", help="只打印 SQL，不写库")
    return p.parse_args(argv)


def _do_steps(cur, args):
    run_statement(cur, "步骤 0: 建表 pv2 (IF NOT EXISTS，照搬 pv1 结构)",
                  SQL_CREATE_TABLE, dry_run=args.dry_run)
    run_statement(cur, "步骤 1: TRUNCATE 清空 pv2", SQL_TRUNCATE,
                  dry_run=args.dry_run)
    run_statement(cur, "步骤 2: 重建 pv2 唯一索引", SQL_REBUILD_INDEX,
                  dry_run=args.dry_run)
    run_statement(cur, f"步骤 3: 第一段纯插入 (tsdate >= {args.since})",
                  SQL_INSERT_FULL, params={"since": args.since},
                  dry_run=args.dry_run)
    run_statement(cur, f"步骤 4: 第二段 upsert (最近 {args.days} 天)",
                  SQL_UPSERT_RECENT, params={"days": args.days},
                  dry_run=args.dry_run)
    run_statement(cur, "步骤 5: 回填 ot", SQL_UPDATE_OT,
                  params={"since": args.since}, dry_run=args.dry_run)


def main(argv=None):
    args = parse_args(argv)

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
    conn = connect(driver, conn_kwargs)
    try:
        conn.autocommit = False
        cur = conn.cursor()
        _do_steps(cur, args)
        conn.commit()
        print("\n✓ 全部完成，事务已提交。")
        if args.verify:
            run_verify(cur)
        if args.compare:
            run_compare(cur, args.since)
    except Exception as exc:
        conn.rollback()
        print(f"\n✗ 出错，已回滚事务：{exc}", file=sys.stderr)
        return 1
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

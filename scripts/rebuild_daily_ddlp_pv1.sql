-- =============================================================================
-- rebuild_daily_ddlp_pv1.sql
-- 删库重建 dlp04.daily_ddlp_pv1：清空 -> 重建唯一索引 -> 从 2026-01-01 起 upsert
--                                  -> 回填 ot -> 校验
-- 在 DBeaver 里整段执行即可（建议用 "Execute SQL Script" / Alt+X 跑全部）。
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 步骤 1：清空表（不可回滚，慎用）
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dlp04.daily_ddlp_pv1;


-- ----------------------------------------------------------------------------
-- 步骤 2：删除可能存在的同名/历史索引，并重建唯一索引
--   注意索引名是 day，不是 daily；这个唯一索引是下面 ON CONFLICT 能工作的前提
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_pv1_plant_day_line;
DROP INDEX IF EXISTS dlp04.idx_pv1_plant_daily_line;
DROP INDEX IF EXISTS idx_pv_plant_daily_line;
DROP INDEX IF EXISTS dlp04.idx_pv1_plant_day_line;

CREATE UNIQUE INDEX idx_pv1_plant_day_line
    ON dlp04.daily_ddlp_pv1 (plant_id, day, line_id);


-- ----------------------------------------------------------------------------
-- 步骤 3：从 public.lds_production_data 汇总，upsert 进 daily_ddlp_pv1
--   取 tsdate >= '2026-01-01' 到今天（不含今天）的全部数据。
--   因为有 ON CONFLICT(plant_id, day, line_id)，这条同时是“全量重建”和“日常刷新”：
--   已存在的键更新、不存在的插入，重复运行幂等、不会产生重复行。
-- ----------------------------------------------------------------------------
INSERT INTO dlp04.daily_ddlp_pv1 (
    plant_id,
    plant_name,
    daily,               -- 存“日”数字
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
    (CAST(to_char(t.tsdate, 'YYYYMMDD') AS INTEGER) / 100) % 100 AS month,
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
        WHERE tsdate >= '2026-01-01'        -- ← 从 50 天窗口改成固定起始日期
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
-- 注意：create_time 在冲突时不更新，保持原始插入时间


-- ----------------------------------------------------------------------------
-- 步骤 4：回填 ot 字段
--   = lds 操作时间(分钟) - T4 红色停机时间(分钟)，再换算成小时
-- ----------------------------------------------------------------------------
UPDATE dlp04.daily_ddlp_pv1 AS pv
SET ot = CASE
           WHEN src.red_downtime IS NULL THEN src.lds_ot / 60.0
           ELSE (src.lds_ot - src.red_downtime) / 60.0
         END
FROM (
    SELECT
        t2.shift_date AS tsdate,
        t2.line_name,
        t2.line_ot * 60.0 AS lds_ot,          -- 小时转回分钟，与原公式匹配
        t3.red_time * 60.0 AS red_downtime    -- 小时转回分钟
    FROM (
        -- t2：按日、产线汇总操作时间（小时）和标准产线名
        SELECT
            t1.shift_date,
            dlp_datasource_relation.name AS line_name,
            SUM(t1.ot) / 60.0 AS line_ot      -- 汇总分钟数并转为小时
        FROM (
            -- t1：提取产线关联键，仅取 2026 年 1 月及以后的生产时间数据
            SELECT
                SUBSTRING(line_name FROM '.*\\.*\\(.*$)') AS l_name,
                *
            FROM public.lds_production_time
            WHERE shift_date >= '2026-01-01'   -- ← 改成直接 >= 2026-01-01，避免漏掉 1 月
        ) t1
        LEFT JOIN dlp_uoc.dlp_datasource_relation
            ON t1.l_name = dlp_datasource_relation.def
        GROUP BY t1.shift_date, dlp_datasource_relation.name
    ) t2
    LEFT JOIN (
        -- t3：汇总 T4 红色停机时间（小时）
        SELECT
            tsdate,
            line,
            SUM(downtime) / 60.0 AS red_time   -- 分钟转小时
        FROM dlp.red_time
        WHERE substr(reason, 1, 2) = 'T4'
        GROUP BY tsdate, line
    ) t3
        ON t2.line_name = t3.line
       AND t2.shift_date = t3.tsdate
) AS src
WHERE pv.day = src.tsdate
  AND pv.line_name = src.line_name;


-- ----------------------------------------------------------------------------
-- 步骤 5：校验 —— 最近 10 天数据，按日期倒序
-- ----------------------------------------------------------------------------
SELECT
    id,
    day,
    plant_id,
    line_id,
    line_name,
    ut,
    qty,
    ot,
    update_time
FROM dlp04.daily_ddlp_pv1
WHERE day >= current_date - interval '10 days'
ORDER BY day DESC, line_id;

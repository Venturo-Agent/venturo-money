-- ════════════════════════════════════════════════════════════════════
-- Migration: 建立 ledger schema（漫途記帳獨立 app）
-- Why: 不污染 yizhan-erp 的 public schema、共用 auth.users 與 Supabase 認證、
--      RLS by user_id（A 用戶看不到 B 用戶資料、即使「自己人用」也守底線）
-- 紅線 #0：沒有 admin / 特權、所有 user 平等、靠 RLS 守
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- 1. Schema
CREATE SCHEMA IF NOT EXISTS ledger;

GRANT USAGE ON SCHEMA ledger TO authenticated;
-- anon 不給 — 必須登入才能用

-- 2. categories（系統預設 + 用戶自訂）
CREATE TABLE IF NOT EXISTS ledger.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  -- user_id NULL = 系統預設、任何登入 user 看得到
  name text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('income', 'fixed', 'adhoc')),
  mode text NOT NULL CHECK (mode IN ('personal', 'company', 'both')),
  color text DEFAULT '#4A4239',
  icon text,
  sort_order int DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_categories_user ON ledger.categories(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_categories_mode_kind ON ledger.categories(mode, kind);

-- 3. records（記帳主表）
CREATE TABLE IF NOT EXISTS ledger.records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mode text NOT NULL CHECK (mode IN ('personal', 'company')),
  occurred_on date NOT NULL DEFAULT CURRENT_DATE,
  description text NOT NULL,
  category_id uuid REFERENCES ledger.categories(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK (kind IN ('income', 'fixed', 'adhoc')),
  -- amount 一律正數、kind 決定 +/- 方向
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_records_user_date ON ledger.records(user_id, occurred_on DESC);
CREATE INDEX IF NOT EXISTS idx_records_user_mode_date ON ledger.records(user_id, mode, occurred_on DESC);
CREATE INDEX IF NOT EXISTS idx_records_user_kind ON ledger.records(user_id, kind);

-- 4. updated_at trigger
CREATE OR REPLACE FUNCTION ledger.tg_set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_records_updated_at ON ledger.records;
CREATE TRIGGER trg_records_updated_at
  BEFORE UPDATE ON ledger.records
  FOR EACH ROW EXECUTE FUNCTION ledger.tg_set_updated_at();

-- ─────────── RLS ───────────
ALTER TABLE ledger.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger.records ENABLE ROW LEVEL SECURITY;

-- categories: 系統預設（user_id IS NULL）任何登入 user 能讀、自訂只能 owner CRUD
DROP POLICY IF EXISTS categories_select ON ledger.categories;
CREATE POLICY categories_select ON ledger.categories
  FOR SELECT TO authenticated
  USING (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS categories_insert ON ledger.categories;
CREATE POLICY categories_insert ON ledger.categories
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS categories_update ON ledger.categories;
CREATE POLICY categories_update ON ledger.categories
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS categories_delete ON ledger.categories;
CREATE POLICY categories_delete ON ledger.categories
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- records: 只有 owner 能 CRUD（最基礎隔離、就算「自己人用」這條也守）
DROP POLICY IF EXISTS records_owner_all ON ledger.records;
CREATE POLICY records_owner_all ON ledger.records
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ─────────── 預設分類 seed（系統內建、user_id IS NULL） ───────────
INSERT INTO ledger.categories (name, kind, mode, color, sort_order) VALUES
  -- 收入類
  ('薪資', 'income', 'personal', '#3D4F3D', 1),
  ('業務收入', 'income', 'both', '#3D4F3D', 2),
  ('訂閱月費', 'income', 'company', '#3D4F3D', 3),
  ('利息 / 投資', 'income', 'both', '#3D4F3D', 4),
  ('其他收入', 'income', 'both', '#3D4F3D', 5),
  -- 固定費用
  ('員工薪資', 'fixed', 'company', '#4A4239', 10),
  ('雲端服務', 'fixed', 'company', '#4A4239', 11),
  ('辦公租金', 'fixed', 'both', '#4A4239', 12),
  ('餐飲', 'fixed', 'personal', '#4A4239', 13),
  ('交通', 'fixed', 'both', '#4A4239', 14),
  ('房租 / 水電', 'fixed', 'personal', '#4A4239', 15),
  ('保險', 'fixed', 'both', '#4A4239', 16),
  ('日用品', 'fixed', 'personal', '#4A4239', 17),
  -- 突發支出
  ('展場 / 行銷', 'adhoc', 'company', '#8B2A1B', 20),
  ('設備購買', 'adhoc', 'both', '#8B2A1B', 21),
  ('醫療', 'adhoc', 'personal', '#8B2A1B', 22),
  ('禮品 / 應酬', 'adhoc', 'both', '#8B2A1B', 23),
  ('旅遊', 'adhoc', 'personal', '#8B2A1B', 24),
  ('其他突發', 'adhoc', 'both', '#8B2A1B', 25)
ON CONFLICT DO NOTHING;

COMMIT;

-- ════════════════════════════════════════════════════════════════════
-- Rollback（萬一爆炸、複製貼上跑）：
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_records_updated_at ON ledger.records;
-- DROP FUNCTION IF EXISTS ledger.tg_set_updated_at();
-- DROP TABLE IF EXISTS ledger.records;
-- DROP TABLE IF EXISTS ledger.categories;
-- DROP SCHEMA IF EXISTS ledger;
-- COMMIT;
-- ════════════════════════════════════════════════════════════════════

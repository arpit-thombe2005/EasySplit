-- EasySplit Database Schema
-- PostgreSQL (Neon)
-- Run this once to set up the database

-- ── Extensions ───────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Drop tables (in dependency order) if rebuilding ──────────────
-- DROP TABLE IF EXISTS notifications CASCADE;
-- DROP TABLE IF EXISTS settlements CASCADE;
-- DROP TABLE IF EXISTS expense_participants CASCADE;
-- DROP TABLE IF EXISTS expenses CASCADE;
-- DROP TABLE IF EXISTS group_members CASCADE;
-- DROP TABLE IF EXISTS groups CASCADE;
-- DROP TABLE IF EXISTS otps CASCADE;
-- DROP TABLE IF EXISTS users CASCADE;

-- ── Users ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(100),
  email       VARCHAR(255) NOT NULL UNIQUE,
  avatar_id   VARCHAR(50) NOT NULL DEFAULT 'avatar_1',
  currency    VARCHAR(10) NOT NULL DEFAULT 'INR',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ── OTPs (for email verification) ────────────────────────────────
CREATE TABLE IF NOT EXISTS otps (
  email       VARCHAR(255) PRIMARY KEY,
  otp         VARCHAR(6) NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otps_expires ON otps(expires_at);

-- ── Groups ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(100) NOT NULL,
  description TEXT,
  created_by  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_locked   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);

-- ── Group Members ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS group_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user  ON group_members(user_id);

-- ── Expenses ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expenses (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  paid_by      UUID NOT NULL REFERENCES users(id),
  title        VARCHAR(200) NOT NULL,
  amount       NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  category     VARCHAR(50) NOT NULL DEFAULT 'Other',
  notes        TEXT,
  split_type   VARCHAR(20) NOT NULL DEFAULT 'equal'
                 CHECK (split_type IN ('equal', 'exact', 'percentage', 'shares')),
  expense_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_group    ON expenses(group_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by  ON expenses(paid_by);
CREATE INDEX IF NOT EXISTS idx_expenses_date     ON expenses(expense_date DESC);

-- ── Expense Participants ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expense_participants (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id   UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id),
  share_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  percentage   NUMERIC(6, 2) DEFAULT 0,
  shares       INTEGER DEFAULT 1,
  UNIQUE(expense_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_ep_expense ON expense_participants(expense_id);
CREATE INDEX IF NOT EXISTS idx_ep_user    ON expense_participants(user_id);

-- ── Settlements ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settlements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user   UUID NOT NULL REFERENCES users(id),
  to_user     UUID NOT NULL REFERENCES users(id),
  group_id    UUID REFERENCES groups(id) ON DELETE SET NULL,
  amount      NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'completed')),
  settled_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settlements_from   ON settlements(from_user);
CREATE INDEX IF NOT EXISTS idx_settlements_to     ON settlements(to_user);
CREATE INDEX IF NOT EXISTS idx_settlements_group  ON settlements(group_id);

-- ── Group Invitations ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS group_invitations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  sender_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(group_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_gi_group    ON group_invitations(group_id);
CREATE INDEX IF NOT EXISTS idx_gi_receiver ON group_invitations(receiver_id);
CREATE INDEX IF NOT EXISTS idx_gi_sender   ON group_invitations(sender_id);

-- ── Notifications ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title        VARCHAR(200) NOT NULL,
  message      TEXT NOT NULL,
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  type         VARCHAR(50),
  reference_id UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- ── User Device Tokens for Push Notifications ──────────────────────
CREATE TABLE IF NOT EXISTS user_devices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token   TEXT NOT NULL UNIQUE,
  device_type VARCHAR(20) CHECK (device_type IN ('android', 'ios', 'web')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);

-- ── Auto-update updated_at trigger ───────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER groups_updated_at
  BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER group_invitations_updated_at
  BEFORE UPDATE ON group_invitations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER user_devices_updated_at
  BEFORE UPDATE ON user_devices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Cleanup expired OTPs (run periodically or via pg_cron) ────────
-- DELETE FROM otps WHERE expires_at < NOW();


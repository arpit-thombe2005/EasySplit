import { neon } from '@neondatabase/serverless';
import 'dotenv/config';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is not set. Check your .env file.');
}

/** Neon PostgreSQL SQL tagged template function */
const sql = neon(process.env.DATABASE_URL);

// Auto-migration helper for is_locked column and user_devices table with retry support for Neon cold starts
(async () => {
  const maxRetries = 5;
  let delay = 1000;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      // 1. Migrate is_locked
      await sql`ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE`;
      console.log('✅ Auto-migration for is_locked column verified.');

      // 1b. Migrate is_archived
      await sql`ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE`;
      console.log('✅ Auto-migration for is_archived column verified.');

      // 2. Migrate user_devices
      await sql`
        CREATE TABLE IF NOT EXISTS user_devices (
          id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          fcm_token   TEXT NOT NULL UNIQUE,
          device_type VARCHAR(20) CHECK (device_type IN ('android', 'ios', 'web')),
          created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
      `;
      await sql`CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);`;
      
      // Ensure the update_updated_at function exists before binding trigger
      await sql`
        CREATE OR REPLACE FUNCTION update_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
          NEW.updated_at = NOW();
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
      `;

      await sql`
        CREATE OR REPLACE TRIGGER user_devices_updated_at
          BEFORE UPDATE ON user_devices
          FOR EACH ROW EXECUTE FUNCTION update_updated_at();
      `;
      console.log('✅ Auto-migration for user_devices table verified.');
      break;
    } catch (err) {
      if (attempt === maxRetries) {
        console.error(`❌ Auto-migration error after ${maxRetries} attempts:`, err);
      } else {
        console.warn(`⚠️ Auto-migration attempt ${attempt}/${maxRetries} failed: ${err.message || err}. Retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
        delay *= 2;
      }
    }
  }
})();

export { sql };

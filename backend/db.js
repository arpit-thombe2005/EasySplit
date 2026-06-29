import { neon } from '@neondatabase/serverless';
import 'dotenv/config';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is not set. Check your .env file.');
}

/** Neon PostgreSQL SQL tagged template function */
const sql = neon(process.env.DATABASE_URL);

// Auto-migration helper for is_locked column
(async () => {
  try {
    await sql`ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE`;
  } catch (err) {
    console.error('Auto-migration error for is_locked column:', err);
  }
})();

export { sql };

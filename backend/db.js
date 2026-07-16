import { neon } from '@neondatabase/serverless';
import 'dotenv/config';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is not set. Check your .env file.');
}

/** Neon PostgreSQL SQL tagged template function */
const sql = neon(process.env.DATABASE_URL);

// Auto-migration helper for is_locked column with retry support for Neon cold starts
(async () => {
  const maxRetries = 5;
  let delay = 1000;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await sql`ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE`;
      console.log('✅ Auto-migration for is_locked column verified.');
      break;
    } catch (err) {
      if (attempt === maxRetries) {
        console.error(`❌ Auto-migration error for is_locked column after ${maxRetries} attempts:`, err);
      } else {
        console.warn(`⚠️ Auto-migration attempt ${attempt}/${maxRetries} failed: ${err.message || err}. Retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
        delay *= 2;
      }
    }
  }
})();

export { sql };

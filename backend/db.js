import { neon } from '@neondatabase/serverless';
import 'dotenv/config';

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is not set. Check your .env file.');
}

/** Neon PostgreSQL SQL tagged template function */
const sql = neon(process.env.DATABASE_URL);

export { sql };

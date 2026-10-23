import { SqliteDatabaseAdapter } from "@elizaos/adapter-sqlite";
import Database from "better-sqlite3";
import path from "path";

/*
 * Vendored from the elizaOS starter v0.1.1 (MIT) — src/database/index.ts,
 * adapted: the Postgres branch was removed; this agent ships SQLite only.
 */

export function initializeDatabase(dataDir: string) {
  const filePath =
    process.env.SQLITE_FILE ?? path.resolve(dataDir, "db.sqlite");
  const db = new SqliteDatabaseAdapter(new Database(filePath));
  return db;
}

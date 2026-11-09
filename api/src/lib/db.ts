import { drizzle } from "drizzle-orm/d1";
import * as schema from "../db/schema";

export function database(d1: D1Database) {
  return drizzle(d1, { schema });
}

export type Database = ReturnType<typeof database>;

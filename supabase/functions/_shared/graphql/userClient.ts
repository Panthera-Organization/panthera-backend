import { createClient } from "@supabase/supabase-js"
import type { Database } from "../db/database.types.ts"
import type { UserClient } from "./rows.ts"

export function createUserClient(url: string, anonKey: string, token?: string | null): UserClient {
  return createClient<Database>(url, anonKey, {
    global: { headers: token ? { Authorization: `Bearer ${token}` } : {} },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
}

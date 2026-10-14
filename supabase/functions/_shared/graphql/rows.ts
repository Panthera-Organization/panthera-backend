import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database } from "../db/database.types.ts"

export type UserClient = SupabaseClient<Database>
export type ProfileRow = Database["public"]["Tables"]["profiles"]["Row"]
export type MembershipRow = Database["public"]["Tables"]["memberships"]["Row"]
export type CompanyRow = Database["public"]["Tables"]["companies"]["Row"]

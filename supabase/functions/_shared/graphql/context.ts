import { createClient } from "@supabase/supabase-js"
import { GraphQLError } from "graphql"
import type { Database } from "../db/database.types.ts"
import { GENERIC_ERROR_MESSAGE } from "./mapPostgresError.ts"
import { createLoaders, type Loaders } from "./loaders.ts"
import type { UserClient } from "./rows.ts"

export type GraphqlContext = {
  supabase: UserClient
  loaders: Loaders
  userId: string | null
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization")
  if (!header) return null
  const [scheme, token] = header.split(/\s+/, 2)
  if (scheme?.toLowerCase() !== "bearer" || !token) return null
  return token
}

export async function createContext(request: Request): Promise<GraphqlContext> {
  const url = Deno.env.get("SUPABASE_URL")
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")
  if (!url || !anonKey) {
    throw new GraphQLError(GENERIC_ERROR_MESSAGE, { extensions: { code: "INTERNAL" } })
  }

  const token = bearerToken(request)
  const supabase = createClient<Database>(url, anonKey, {
    global: { headers: token ? { Authorization: `Bearer ${token}` } : {} },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })

  let userId: string | null = null
  if (token) {
    const { data, error } = await supabase.auth.getUser(token)
    if (!error && data.user) userId = data.user.id
  }

  return {
    supabase,
    loaders: createLoaders(supabase),
    userId,
  }
}

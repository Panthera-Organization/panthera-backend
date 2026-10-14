import { GraphQLError } from "graphql"
import { GENERIC_ERROR_MESSAGE } from "./mapPostgresError.ts"
import { createLoaders, type Loaders } from "./loaders.ts"
import type { UserClient } from "./rows.ts"
import { createUserClient } from "./userClient.ts"
import { userIdFromGetUser } from "./userId.ts"

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
  const supabase = createUserClient(url, anonKey, token)

  let userId: string | null = null
  if (token) userId = userIdFromGetUser(await supabase.auth.getUser(token))

  return {
    supabase,
    loaders: createLoaders(supabase),
    userId,
  }
}

import DataLoader from "dataloader"
import { GraphQLError } from "graphql"
import { mapPostgresError } from "./mapPostgresError.ts"
import type { CompanyRow, MembershipRow, ProfileRow, UserClient } from "./rows.ts"

function throwMapped(error: { code?: string }): never {
  const mapped = mapPostgresError(error.code ?? "")
  throw new GraphQLError(mapped.message, { extensions: mapped.extensions })
}

export type Loaders = {
  profileById: DataLoader<string, ProfileRow | null>
  companyById: DataLoader<string, CompanyRow | null>
  membershipsByUserId: DataLoader<string, MembershipRow[]>
}

export function createLoaders(supabase: UserClient): Loaders {
  return {
    profileById: new DataLoader(async (ids) => {
      const { data, error } = await supabase.from("profiles").select("*").in("id", [...ids])
      if (error) throwMapped(error)
      const byId = new Map((data ?? []).map((row) => [row.id, row]))
      return ids.map((id) => byId.get(id) ?? null)
    }),

    companyById: new DataLoader(async (ids) => {
      const { data, error } = await supabase.from("companies").select("*").in("id", [...ids])
      if (error) throwMapped(error)
      const byId = new Map((data ?? []).map((row) => [row.id, row]))
      return ids.map((id) => byId.get(id) ?? null)
    }),

    membershipsByUserId: new DataLoader(async (userIds) => {
      const { data, error } = await supabase
        .from("memberships")
        .select("*")
        .in("user_id", [...userIds])
        .order("created_at")
      if (error) throwMapped(error)
      const groups = new Map<string, MembershipRow[]>(userIds.map((id) => [id, []]))
      for (const row of data ?? []) groups.get(row.user_id)?.push(row)
      return userIds.map((id) => groups.get(id) ?? [])
    }),
  }
}

import { GraphQLError } from "graphql"
import type { GraphqlContext } from "../context.ts"
import type { Resolvers } from "../generated/resolvers-types.ts"
import { GENERIC_ERROR_MESSAGE } from "../mapPostgresError.ts"
import { throwMapped } from "../throwMapped.ts"
import type { MembershipRow, ProfileRow } from "../rows.ts"

const memberRole: Record<MembershipRow["role"], "OWNER" | "ADMIN" | "TEACHER" | "STUDENT"> = {
  owner: "OWNER",
  admin: "ADMIN",
  teacher: "TEACHER",
  student: "STUDENT",
}

function throwClientError(code: "UNAUTHENTICATED" | "INTERNAL"): never {
  throw new GraphQLError(GENERIC_ERROR_MESSAGE, { extensions: { code } })
}

function requireUserId(userId: string | null): string {
  if (!userId) throwClientError("UNAUTHENTICATED")
  return userId
}

async function loadViewer(ctx: GraphqlContext, userId: string): Promise<ProfileRow> {
  const profile = await ctx.loaders.profileById.load(userId)
  if (!profile) throwClientError("INTERNAL")
  return profile
}

export const resolvers: Resolvers = {
  Query: {
    viewer: (_parent, _args, ctx) => {
      if (!ctx.userId) return null
      return ctx.loaders.profileById.load(ctx.userId)
    },
  },

  Viewer: {
    fullName: (profile) => profile.full_name,
    profile: (profile) => profile,
    memberships: (profile, _args, ctx) => ctx.loaders.membershipsByUserId.load(profile.id),
  },

  Profile: {
    fullName: (profile) => profile.full_name,
    timezone: (profile) => profile.timezone,
  },

  Membership: {
    role: (membership) => memberRole[membership.role],
    canTeach: (membership) => membership.can_teach,
    company: (membership, _args, ctx) => ctx.loaders.companyById.load(membership.company_id),
  },

  Company: {
    isPersonal: (company) => company.is_personal,
  },

  Mutation: {
    updateProfile: async (_parent, { input }, ctx) => {
      const userId = requireUserId(ctx.userId)
      // An omitted field and an explicit null leave that column unchanged.
      const patch: { full_name?: string; timezone?: string } = {}
      if (input.fullName != null) patch.full_name = input.fullName
      if (input.timezone != null) patch.timezone = input.timezone
      if (Object.keys(patch).length === 0) return loadViewer(ctx, userId)

      const { data, error } = await ctx.supabase
        .from("profiles")
        .update(patch)
        .eq("id", userId)
        .select("*")
        .single()
      if (error) throwMapped(error)
      if (!data) throwClientError("INTERNAL")
      return data
    },

    createPersonalWorkspace: async (_parent, { input }, ctx) => {
      const userId = requireUserId(ctx.userId)
      const { error } = await ctx.supabase.rpc(
        "create_personal_workspace",
        input.name == null ? {} : { p_name: input.name },
      )
      if (error) throwMapped(error)
      return loadViewer(ctx, userId)
    },
  },
}

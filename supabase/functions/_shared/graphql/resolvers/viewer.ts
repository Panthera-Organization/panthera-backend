import { GraphQLError } from "graphql"
import { GENERIC_ERROR_MESSAGE } from "../mapPostgresError.ts"
import type { Resolvers } from "../generated/resolvers-types.ts"
import type { MembershipRow, ProfileRow } from "../rows.ts"

const memberRole: Record<MembershipRow["role"], "OWNER" | "ADMIN" | "TEACHER" | "STUDENT"> = {
  owner: "OWNER",
  admin: "ADMIN",
  teacher: "TEACHER",
  student: "STUDENT",
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
    profile: async (profile, _args, ctx): Promise<ProfileRow> => {
      const row = await ctx.loaders.profileById.load(profile.id)
      if (!row) {
        throw new GraphQLError(GENERIC_ERROR_MESSAGE, { extensions: { code: "NOT_FOUND" } })
      }
      return row
    },
    memberships: (profile, _args, ctx) => ctx.loaders.membershipsByUserId.load(profile.id),
  },

  Profile: {
    fullName: (profile) => profile.full_name,
  },

  Membership: {
    role: (membership) => memberRole[membership.role],
    company: (membership, _args, ctx) => ctx.loaders.companyById.load(membership.company_id),
  },

  Company: {
    isPersonal: (company) => company.is_personal,
  },
}

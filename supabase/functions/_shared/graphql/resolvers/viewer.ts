import type { Resolvers } from "../generated/resolvers-types.ts"
import type { MembershipRow } from "../rows.ts"

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
    profile: (profile) => profile,
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

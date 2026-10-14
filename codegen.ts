import type { CodegenConfig } from "@graphql-codegen/cli"

const config: CodegenConfig = {
  schema: "supabase/functions/_shared/graphql/schema.graphql",
  generates: {
    "supabase/functions/_shared/graphql/generated/resolvers-types.ts": {
      plugins: ["typescript", "typescript-resolvers"],
      config: {
        contextType: "../context.ts#GraphqlContext",
        useTypeImports: true,
        enumsAsTypes: true,
        mappers: {
          Viewer: "../rows.ts#ProfileRow",
          Profile: "../rows.ts#ProfileRow",
          Membership: "../rows.ts#MembershipRow",
          Company: "../rows.ts#CompanyRow",
        },
      },
    },
  },
}

export default config

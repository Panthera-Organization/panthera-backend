import { GraphQLError } from "graphql"
import { mapPostgresError } from "./mapPostgresError.ts"

export function throwMapped(error: { code?: string }): never {
  const mapped = mapPostgresError(error.code ?? "")
  throw new GraphQLError(mapped.message, { extensions: mapped.extensions })
}

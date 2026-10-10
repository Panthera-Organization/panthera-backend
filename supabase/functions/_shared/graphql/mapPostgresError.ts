// Maps a Postgres SQLSTATE to the GraphQL error the phone is allowed to see.
// PB-18 calls this when Yoga is built. Pass only the SQLSTATE. The Postgres
// message, details, and hint stay on the server.

export const GENERIC_ERROR_MESSAGE = "Request failed."

export const postgresErrorCodes = {
  "23514": "CHECK_FAILED",
  "42501": "FORBIDDEN",
  "23503": "CONFLICT",
  "22023": "BAD_INPUT",
  "28000": "UNAUTHENTICATED",
  "P0002": "NOT_FOUND",
  "23505": "ALREADY_EXISTS",
} as const

export type PostgresErrorCode = keyof typeof postgresErrorCodes
export type GraphqlErrorCode = (typeof postgresErrorCodes)[PostgresErrorCode] | "INTERNAL"

export type MappedPostgresError = {
  message: string
  extensions: { code: GraphqlErrorCode }
}

export function mapPostgresError(sqlstate: string): MappedPostgresError {
  const code = postgresErrorCodes[sqlstate as PostgresErrorCode] ?? "INTERNAL"
  return {
    message: GENERIC_ERROR_MESSAGE,
    extensions: { code },
  }
}

import { assertEquals } from "jsr:@std/assert"
import { GENERIC_ERROR_MESSAGE, mapPostgresError, postgresErrorCodes } from "./mapPostgresError.ts"

Deno.test("each mapped SQLSTATE returns its GraphQL code", () => {
  for (const [sqlstate, code] of Object.entries(postgresErrorCodes)) {
    assertEquals(mapPostgresError(sqlstate), {
      message: GENERIC_ERROR_MESSAGE,
      extensions: { code },
    })
  }
})

Deno.test("a check violation and an RLS denial return different codes", () => {
  assertEquals(mapPostgresError("23514").extensions.code, "CHECK_FAILED")
  assertEquals(mapPostgresError("42501").extensions.code, "FORBIDDEN")
})

Deno.test("an unmapped SQLSTATE returns INTERNAL and the generic message", () => {
  for (const sqlstate of ["23502", "XX000", ""]) {
    assertEquals(mapPostgresError(sqlstate), {
      message: GENERIC_ERROR_MESSAGE,
      extensions: { code: "INTERNAL" },
    })
  }
})

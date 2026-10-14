import { assertEquals, assertThrows } from "jsr:@std/assert"
import { userIdFromGetUser } from "./userId.ts"

Deno.test("a valid getUser result returns the user id", () => {
  assertEquals(userIdFromGetUser({ data: { user: { id: "user-1" } }, error: null }), "user-1")
})

Deno.test("a rejected token returns no user id", () => {
  assertEquals(userIdFromGetUser({ data: { user: null }, error: { status: 401 } }), null)
  assertEquals(userIdFromGetUser({ data: { user: null }, error: { status: 403 } }), null)
})

Deno.test("an auth outage is thrown", () => {
  const error = { status: 503 }
  const thrown = assertThrows(() => userIdFromGetUser({ data: { user: null }, error }))
  assertEquals(thrown, error)
})

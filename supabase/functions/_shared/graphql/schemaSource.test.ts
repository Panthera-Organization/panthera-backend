import { assertEquals } from "jsr:@std/assert"
import { schemaSource } from "./schemaSource.ts"

Deno.test("the bundled schema text matches schema.graphql", async () => {
  const file = await Deno.readTextFile(new URL("./schema.graphql", import.meta.url))
  assertEquals(schemaSource, file)
})

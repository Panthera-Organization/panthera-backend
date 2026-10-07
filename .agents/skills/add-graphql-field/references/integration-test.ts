// Runs an operation through Yoga against the local Supabase stack, as different users.
// Get tokens by signing in seeded test users with the local anon key.
import { assertEquals } from 'jsr:@std/assert'
import { yoga } from '../_shared/graphql/createYoga.ts'

async function run(token: string, query: string, variables = {}) {
  const res = await yoga.fetch('http://localhost/graphql', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify({ query, variables }),
  })
  return res.json()
}

const QUERY = `query ($id: ID!) { homework(id: $id) { id title } }`

Deno.test('teacher of company A can read the homework', async () => {
  const { data } = await run(teacherAToken, QUERY, { id: homeworkAId })
  assertEquals(data.homework.id, homeworkAId)
})

Deno.test('teacher of company B gets null (RLS hides it)', async () => {
  const { data } = await run(teacherBToken, QUERY, { id: homeworkAId })
  assertEquals(data.homework, null)
})

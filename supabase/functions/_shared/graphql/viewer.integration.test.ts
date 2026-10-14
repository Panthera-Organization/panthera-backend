import { assertEquals } from "jsr:@std/assert"
import { createClient } from "@supabase/supabase-js"
import { graphqlResponse, yoga } from "./createYoga.ts"

const VIEWER = `
  query {
    viewer {
      id
      fullName
      profile { id fullName }
      memberships {
        role
        company { name isPersonal }
      }
    }
  }
`

type ViewerPayload = {
  data?: {
    viewer: {
      id: string
      fullName: string
      profile: { id: string; fullName: string }
      memberships: { role: string; company: { name: string; isPersonal: boolean } | null }[]
    } | null
  }
  errors?: { message: string }[]
}

async function run(token: string | null, query: string): Promise<ViewerPayload> {
  const headers: Record<string, string> = { "content-type": "application/json" }
  if (token) headers.authorization = `Bearer ${token}`
  const response = await yoga.fetch("http://localhost/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({ query }),
  })
  return response.json()
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Missing ${name}`)
  return value
}

async function signUp(fullName: string): Promise<string> {
  const client = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_ANON_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const email = `viewer-${crypto.randomUUID()}@test.panthera.local`
  const { data, error } = await client.auth.signUp({
    email,
    password: "viewer-test-password",
    options: { data: { full_name: fullName } },
  })
  if (error || !data.session) throw new Error(error?.message ?? "Sign-up returned no session")
  return data.session.access_token
}

async function createWorkspace(token: string, name: string): Promise<void> {
  const client = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { error } = await client.rpc("create_personal_workspace", { p_name: name })
  if (error) throw new Error(error.message)
}

Deno.test("a missing token resolves viewer to null", async () => {
  const body = await run(null, VIEWER)
  assertEquals(body.errors, undefined)
  assertEquals(body.data?.viewer, null)
})

Deno.test("an invalid token resolves viewer to null", async () => {
  const body = await run("not-a-token", VIEWER)
  assertEquals(body.errors, undefined)
  assertEquals(body.data?.viewer, null)
})

Deno.test("the edge function path resolves viewer", async () => {
  const response = await graphqlResponse(new Request("http://localhost/functions/v1/graphql", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query: VIEWER }),
  }))
  const body: ViewerPayload = await response.json()
  assertEquals(response.status, 200)
  assertEquals(body.data?.viewer, null)
})

Deno.test("an unknown field is rejected", async () => {
  const body = await run(null, "query { viewer { missingField } }")
  assertEquals(body.data, undefined)
  if (!body.errors?.length) throw new Error("Expected a validation error")
})

Deno.test("a user sees only their own company", async () => {
  const ada = await signUp("Ada Alpha")
  const bea = await signUp("Bea Beta")
  await createWorkspace(ada, "Alpha Studio")
  await createWorkspace(bea, "Beta Studio")

  const adaBody = await run(ada, VIEWER)
  const beaBody = await run(bea, VIEWER)
  const adaViewer = adaBody.data?.viewer
  const beaViewer = beaBody.data?.viewer
  if (!adaViewer || !beaViewer) throw new Error("Expected both viewers")

  assertEquals(adaViewer.fullName, "Ada Alpha")
  assertEquals(adaViewer.profile.fullName, "Ada Alpha")
  assertEquals(adaViewer.profile.id, adaViewer.id)
  assertEquals(adaViewer.memberships.length, 1)
  assertEquals(adaViewer.memberships[0].role, "OWNER")
  assertEquals(adaViewer.memberships[0].company, { name: "Alpha Studio", isPersonal: true })

  assertEquals(beaViewer.fullName, "Bea Beta")
  assertEquals(beaViewer.memberships.length, 1)
  assertEquals(beaViewer.memberships[0].company?.name, "Beta Studio")
  const beaNames = beaViewer.memberships.map((membership) => membership.company?.name)
  if (beaNames.includes("Alpha Studio")) throw new Error("Bea can see Ada's company")
})

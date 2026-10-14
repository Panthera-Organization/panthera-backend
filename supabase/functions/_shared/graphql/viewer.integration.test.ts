import { assertEquals } from "jsr:@std/assert"
import { graphqlResponse, yoga } from "./createYoga.ts"
import { createUserClient } from "./userClient.ts"

const VIEWER = `
  query {
    viewer {
      id
      fullName
      profile { id fullName timezone }
      memberships {
        role
        canTeach
        company { name isPersonal }
      }
    }
  }
`

const UPDATE_PROFILE = `
  mutation ($input: UpdateProfileInput!) {
    updateProfile(input: $input) {
      id
      fullName
      profile { id fullName timezone }
      memberships { role canTeach company { name isPersonal } }
    }
  }
`

const CREATE_WORKSPACE = `
  mutation ($input: CreatePersonalWorkspaceInput!) {
    createPersonalWorkspace(input: $input) {
      fullName
      profile { fullName timezone }
      memberships { role canTeach company { name isPersonal } }
    }
  }
`

type Membership = {
  role: string
  canTeach: boolean
  company: { name: string; isPersonal: boolean } | null
}

type Viewer = {
  id: string
  fullName: string
  profile: { id: string; fullName: string; timezone: string }
  memberships: Membership[]
}

type GraphqlError = { message: string; extensions?: { code?: string } }

type GraphqlBody<T> = {
  data?: T
  errors?: GraphqlError[]
}

type ViewerPayload = GraphqlBody<{ viewer: Viewer | null }>

async function execute<T>(
  token: string | null,
  query: string,
  variables?: Record<string, unknown>,
): Promise<GraphqlBody<T>> {
  const headers: Record<string, string> = { "content-type": "application/json" }
  if (token) headers.authorization = `Bearer ${token}`
  const response = await yoga.fetch("http://localhost/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({ query, variables }),
  })
  return response.json()
}

function assertErrorCode(body: GraphqlBody<unknown>, code: string) {
  assertEquals(body.errors?.length, 1)
  assertEquals(body.errors?.[0]?.message, "Request failed.")
  assertEquals(body.errors?.[0]?.extensions?.code, code)
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Missing ${name}`)
  return value
}

async function signUp(fullName: string): Promise<string> {
  const client = createUserClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_ANON_KEY"))
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
  const client = createUserClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_ANON_KEY"), token)
  const { error } = await client.rpc("create_personal_workspace", { p_name: name })
  if (error) throw new Error(error.message)
}

Deno.test("a missing token resolves viewer to null", async () => {
  const body = await execute<{ viewer: Viewer | null }>(null, VIEWER)
  assertEquals(body.errors, undefined)
  assertEquals(body.data?.viewer, null)
})

Deno.test("an invalid token resolves viewer to null", async () => {
  const body = await execute<{ viewer: Viewer | null }>("not-a-token", VIEWER)
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
  const body = await execute<{ viewer: Viewer | null }>(null, "query { viewer { missingField } }")
  assertEquals(body.data, undefined)
  if (!body.errors?.length) throw new Error("Expected a validation error")
})

Deno.test("a user sees only their own company", async () => {
  const ada = await signUp("Ada Alpha")
  const bea = await signUp("Bea Beta")
  await createWorkspace(ada, "Alpha Studio")
  await createWorkspace(bea, "Beta Studio")

  const adaBody = await execute<{ viewer: Viewer | null }>(ada, VIEWER)
  const beaBody = await execute<{ viewer: Viewer | null }>(bea, VIEWER)
  const adaViewer = adaBody.data?.viewer
  const beaViewer = beaBody.data?.viewer
  if (!adaViewer || !beaViewer) throw new Error("Expected both viewers")

  assertEquals(adaViewer.fullName, "Ada Alpha")
  assertEquals(adaViewer.profile.fullName, "Ada Alpha")
  assertEquals(adaViewer.profile.id, adaViewer.id)
  assertEquals(adaViewer.profile.timezone, "Europe/Warsaw")
  assertEquals(adaViewer.memberships.length, 1)
  assertEquals(adaViewer.memberships[0].role, "OWNER")
  assertEquals(adaViewer.memberships[0].canTeach, true)
  assertEquals(adaViewer.memberships[0].company, { name: "Alpha Studio", isPersonal: true })

  assertEquals(beaViewer.fullName, "Bea Beta")
  assertEquals(beaViewer.memberships.length, 1)
  assertEquals(beaViewer.memberships[0].canTeach, true)
  assertEquals(beaViewer.memberships[0].company?.name, "Beta Studio")
  const beaNames = beaViewer.memberships.map((membership) => membership.company?.name)
  if (beaNames.includes("Alpha Studio")) throw new Error("Bea can see Ada's company")
})

Deno.test("a new user has no company", async () => {
  const token = await signUp("Ada Alpha")
  const body = await execute<{ viewer: Viewer | null }>(token, VIEWER)
  assertEquals(body.errors, undefined)
  assertEquals(body.data?.viewer?.memberships, [])
  assertEquals(body.data?.viewer?.profile.timezone, "Europe/Warsaw")
})

Deno.test("updateProfile changes the caller's name and timezone", async () => {
  const token = await signUp("Ada Alpha")

  const renamed = await execute<{ updateProfile: Viewer }>(token, UPDATE_PROFILE, {
    input: { fullName: "Ada Renamed" },
  })
  assertEquals(renamed.errors, undefined)
  assertEquals(renamed.data?.updateProfile.fullName, "Ada Renamed")
  assertEquals(renamed.data?.updateProfile.profile.fullName, "Ada Renamed")
  assertEquals(renamed.data?.updateProfile.profile.timezone, "Europe/Warsaw")

  const zoned = await execute<{ updateProfile: Viewer }>(token, UPDATE_PROFILE, {
    input: { timezone: "Europe/London" },
  })
  assertEquals(zoned.errors, undefined)
  assertEquals(zoned.data?.updateProfile.fullName, "Ada Renamed")
  assertEquals(zoned.data?.updateProfile.profile.timezone, "Europe/London")

  const keptName = await execute<{ updateProfile: Viewer }>(token, UPDATE_PROFILE, {
    input: { fullName: null, timezone: "America/New_York" },
  })
  assertEquals(keptName.errors, undefined)
  assertEquals(keptName.data?.updateProfile.fullName, "Ada Renamed")
  assertEquals(keptName.data?.updateProfile.profile.timezone, "America/New_York")

  const cleared = await execute<{ updateProfile: Viewer }>(token, UPDATE_PROFILE, {
    input: { fullName: "" },
  })
  assertEquals(cleared.errors, undefined)
  assertEquals(cleared.data?.updateProfile.fullName, "")
  assertEquals(cleared.data?.updateProfile.profile.timezone, "America/New_York")
})

Deno.test("updateProfile leaves another user's profile unchanged", async () => {
  const ada = await signUp("Ada Alpha")
  const bea = await signUp("Bea Beta")
  const updated = await execute<{ updateProfile: Viewer }>(ada, UPDATE_PROFILE, {
    input: { fullName: "Ada Renamed", timezone: "Europe/London" },
  })
  assertEquals(updated.errors, undefined)

  const beaBody = await execute<{ viewer: Viewer | null }>(bea, VIEWER)
  assertEquals(beaBody.data?.viewer?.fullName, "Bea Beta")
  assertEquals(beaBody.data?.viewer?.profile.timezone, "Europe/Warsaw")
})

Deno.test("an empty updateProfile input returns the current viewer", async () => {
  const token = await signUp("Ada Alpha")
  const body = await execute<{ updateProfile: Viewer }>(token, UPDATE_PROFILE, { input: {} })
  assertEquals(body.errors, undefined)
  assertEquals(body.data?.updateProfile.fullName, "Ada Alpha")
  assertEquals(body.data?.updateProfile.profile.timezone, "Europe/Warsaw")
})

Deno.test("an unknown timezone is rejected and the profile stays unchanged", async () => {
  const token = await signUp("Ada Alpha")
  const body = await execute(token, UPDATE_PROFILE, { input: { timezone: "Not/AZone" } })
  assertErrorCode(body, "CHECK_FAILED")

  const viewer = await execute<{ viewer: Viewer | null }>(token, VIEWER)
  assertEquals(viewer.data?.viewer?.profile.timezone, "Europe/Warsaw")
  assertEquals(viewer.data?.viewer?.fullName, "Ada Alpha")
})

Deno.test("createPersonalWorkspace creates one teaching owner membership", async () => {
  const token = await signUp("Ada Alpha")
  const created = await execute<{ createPersonalWorkspace: Viewer }>(token, CREATE_WORKSPACE, {
    input: { name: "Alpha Studio" },
  })
  assertEquals(created.errors, undefined)
  assertEquals(created.data?.createPersonalWorkspace.memberships, [{
    role: "OWNER",
    canTeach: true,
    company: { name: "Alpha Studio", isPersonal: true },
  }])

  const again = await execute(token, CREATE_WORKSPACE, { input: { name: "Again" } })
  assertErrorCode(again, "ALREADY_EXISTS")
})

Deno.test("createPersonalWorkspace uses the profile name when name is omitted", async () => {
  const token = await signUp("Ada Alpha")
  const created = await execute<{ createPersonalWorkspace: Viewer }>(token, CREATE_WORKSPACE, {
    input: {},
  })
  assertEquals(created.errors, undefined)
  assertEquals(created.data?.createPersonalWorkspace.memberships[0]?.company?.name, "Ada Alpha")
  assertEquals(created.data?.createPersonalWorkspace.memberships[0]?.canTeach, true)
})

Deno.test("a mutation without a token is unauthenticated", async () => {
  const update = await execute(null, UPDATE_PROFILE, { input: { fullName: "Ada" } })
  assertErrorCode(update, "UNAUTHENTICATED")
  const create = await execute(null, CREATE_WORKSPACE, { input: { name: "Studio" } })
  assertErrorCode(create, "UNAUTHENTICATED")
})

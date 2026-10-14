import { createGraphqlYoga } from "../supabase/functions/_shared/graphql/createYoga.ts"

const yoga = createGraphqlYoga({ graphiql: true })

function readStatusEnv(text: string): void {
  for (const line of text.split("\n")) {
    const match = line.match(/^(?:export\s+)?([A-Z0-9_]+)="?([^"\n]*)"?$/)
    if (!match) continue
    const [, name, value] = match
    if (!name || !value) continue
    if (name === "API_URL" && !Deno.env.get("SUPABASE_URL")) Deno.env.set("SUPABASE_URL", value)
    if (name === "ANON_KEY" && !Deno.env.get("SUPABASE_ANON_KEY")) Deno.env.set("SUPABASE_ANON_KEY", value)
  }
}

if (!Deno.env.get("SUPABASE_URL") || !Deno.env.get("SUPABASE_ANON_KEY")) {
  const status = new Deno.Command("supabase", {
    args: ["status", "-o", "env"],
    stdout: "piped",
    stderr: "piped",
  })
  const result = await status.output()
  if (result.code === 0) readStatusEnv(new TextDecoder().decode(result.stdout))
}

if (!Deno.env.get("SUPABASE_URL") || !Deno.env.get("SUPABASE_ANON_KEY")) {
  console.error("Set SUPABASE_URL and SUPABASE_ANON_KEY, or start the local stack with supabase start.")
  Deno.exit(1)
}

console.log("GraphQL dev server at http://0.0.0.0:4000/graphql")
Deno.serve({ hostname: "0.0.0.0", port: 4000 }, (request) => yoga.fetch(request))

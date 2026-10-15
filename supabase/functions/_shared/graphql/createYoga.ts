import { createSchema, createYoga, type YogaInitialContext } from "graphql-yoga"
import { createContext, type GraphqlContext } from "./context.ts"
import { resolvers } from "./resolvers/viewer.ts"

// The deploy bundler rejects `with { type: "text" }`.
const schemaSource = Deno.readTextFileSync(new URL("./schema.graphql", import.meta.url))

export function createGraphqlYoga(options: { graphiql: boolean }) {
  return createYoga<YogaInitialContext, GraphqlContext>({
    schema: createSchema({
      typeDefs: schemaSource,
      resolvers,
    }),
    graphqlEndpoint: "/graphql",
    graphiql: options.graphiql,
    landingPage: false,
    maskedErrors: true,
    cors: {
      origin: "*",
      credentials: false,
      allowedHeaders: ["content-type", "authorization"],
      methods: ["GET", "POST", "OPTIONS"],
    },
    context: ({ request }) => createContext(request),
  })
}

export const yoga = createGraphqlYoga({ graphiql: false })

export function graphqlResponse(request: Request): Promise<Response> {
  const url = new URL(request.url)
  url.pathname = "/graphql"
  return Promise.resolve(yoga.fetch(new Request(url, request)))
}

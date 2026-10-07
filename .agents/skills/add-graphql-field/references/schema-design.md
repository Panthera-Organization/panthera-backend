# Schema design rules

## Naming
- camelCase fields, PascalCase types, SCREAMING_CASE enum values.
- Translate snake_case columns in resolvers (`due_at` → `dueAt`).

## Types
- Every object type has `id: ID!`.
- Fixed value sets are enums mirroring the Postgres enum.
- Timestamps use the `DateTime` scalar (ISO 8601). If it isn't declared yet, add `scalar DateTime` and its resolver (for example from `graphql-scalars`).
- Files are exposed as Storage paths (`imagePath: String`). The app uploads and downloads files through Storage directly.

## Nullability follows RLS
- A related object the user may not be allowed to see is **nullable**, because RLS can hide it.
- Use non-null only when the value is guaranteed.
- Lists are `[Thing!]!`: never null, possibly empty.

## Mutations
- One `input` argument with an input type.
- Return the changed object(s) with `id`, including related objects whose fields changed. This lets Apollo update every screen automatically.

```graphql
type Homework {
  id: ID!
  title: String!
  dueAt: DateTime!
  exercises: [HomeworkExercise!]!
  author: Profile          # nullable: teacher may be deleted or hidden by RLS
}

input SubmitAnswerInput {
  assignmentId: ID!
  exerciseId: ID!
  text: String
  imagePath: String
}

type Answer {
  id: ID!
  text: String
  imagePath: String
  assignment: Assignment!  # returned so the status change reaches the cache
}

type Mutation {
  submitAnswer(input: SubmitAnswerInput!): Answer!
}
```

## Changing existing fields (additive only)
- Add fields, types and enum values freely.
- Never remove or rename a field in one release; old app versions still query it. Deprecate instead, and remove it in a later release:

  ```graphql
  fullName: String! @deprecated(reason: "Use displayName")
  ```

- Never tighten an argument or input field from nullable to non-null in one step.

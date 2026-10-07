// supabase/functions/_shared/graphql/resolvers/homework.ts
import { GraphQLError } from 'npm:graphql'
import type { Resolvers } from '../generated/resolvers-types.ts'

export const homeworkResolvers: Resolvers = {
  Query: {
    // RLS decides visibility: an inaccessible id simply resolves to null
    homework: (_p, { id }, ctx) => ctx.loaders.homeworkById.load(id),
  },

  Homework: {
    dueAt: (h) => h.due_at,                                         // snake_case → camelCase
    exercises: (h, _a, ctx) => ctx.loaders.exercisesByHomeworkId.load(h.id),
    author: (h, _a, ctx) => (h.created_by ? ctx.loaders.profileById.load(h.created_by) : null),
  },

  Mutation: {
    submitAnswer: async (_p, { input }, ctx) => {
      if (!ctx.userId) {
        throw new GraphQLError('Sign in required', { extensions: { code: 'UNAUTHENTICATED' } })
      }
      // Status rules live in the database (trigger/function); the resolver just calls it.
      // submit_answer is security INVOKER (the default): a student submitting their own
      // answer is fully covered by RLS, so it must not be security definer.
      const { data, error } = await ctx.supabase
        .rpc('submit_answer', {
          p_assignment_id: input.assignmentId,
          p_exercise_id: input.exerciseId,
          p_text: input.text,
          p_image_path: input.imagePath,
        })
        .single()
      if (error) {
        throw new GraphQLError(error.message, { extensions: { code: 'BAD_USER_INPUT' } })
      }
      return data // must include id; the Answer.assignment resolver returns the updated status
    },
  },
}

// Error codes for expected failures: UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, BAD_USER_INPUT.
// Let unexpected errors propagate; Yoga masks them in production.

// supabase/functions/_shared/graphql/loaders.ts
// createLoaders(supabase) is called once per request in context.ts,
// with the user-scoped client. Never create loaders at module level:
// a shared cache would serve one user's rows to another, bypassing RLS.

import DataLoader from 'npm:dataloader'

export function createLoaders(supabase: UserClient) {
  return {
    // By id: return results in key order; missing (or RLS-hidden) → null
    homeworkById: new DataLoader<string, HomeworkRow | null>(async (ids) => {
      const { data, error } = await supabase.from('homeworks').select('*').in('id', ids)
      if (error) throw error
      const byId = new Map(data.map((r) => [r.id, r]))
      return ids.map((id) => byId.get(id) ?? null)
    }),

    // One-to-many: group child rows by parent id; no children → []
    exercisesByHomeworkId: new DataLoader<string, HomeworkExerciseRow[]>(async (ids) => {
      const { data, error } = await supabase
        .from('homework_exercises')
        .select('*')
        .in('homework_id', ids)
        .order('position')
      if (error) throw error
      const groups = new Map<string, HomeworkExerciseRow[]>(ids.map((id) => [id, []]))
      for (const row of data) groups.get(row.homework_id)?.push(row)
      return ids.map((id) => groups.get(id) ?? [])
    }),
  }
}

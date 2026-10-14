type GetUserResult = {
  data: { user: { id: string } | null }
  error: { status?: number } | null
}

export function userIdFromGetUser(result: GetUserResult): string | null {
  const { data, error } = result
  if (!error) return data.user?.id ?? null
  if (error.status === 401 || error.status === 403) return null
  throw error
}

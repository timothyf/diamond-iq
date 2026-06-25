const ADMIN_API_TOKEN = import.meta.env.VITE_ADMIN_API_TOKEN || ''

export function adminRequestHeaders(headers = {}) {
  if (!ADMIN_API_TOKEN) return headers

  return {
    ...headers,
    Authorization: `Bearer ${ADMIN_API_TOKEN}`,
  }
}

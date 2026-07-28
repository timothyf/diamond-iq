const ADMIN_API_TOKEN = import.meta.env.VITE_ADMIN_API_TOKEN || ''
export const USER_TOKEN_STORAGE_KEY = 'diamondiq_user_token'

export function adminRequestHeaders(headers = {}) {
  let userToken = ''
  try {
    if (typeof localStorage !== 'undefined' && typeof localStorage.getItem === 'function') {
      userToken = localStorage.getItem(USER_TOKEN_STORAGE_KEY) || ''
    }
  } catch {
    userToken = ''
  }
  if (userToken) return { ...headers, Authorization: `Bearer ${userToken}` }
  if (!ADMIN_API_TOKEN) return headers

  return {
    ...headers,
    Authorization: `Bearer ${ADMIN_API_TOKEN}`,
  }
}

export function authRequestHeaders(headers = {}) {
  return adminRequestHeaders(headers)
}

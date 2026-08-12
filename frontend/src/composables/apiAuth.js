import { frontendConfig } from '../config'

export const USER_TOKEN_STORAGE_KEY = 'ninelens_user_token'

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
  if (!frontendConfig.adminApiToken) return headers

  return {
    ...headers,
    Authorization: `Bearer ${frontendConfig.adminApiToken}`,
  }
}

export function authRequestHeaders(headers = {}) {
  return adminRequestHeaders(headers)
}

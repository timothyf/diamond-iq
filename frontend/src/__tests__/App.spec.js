import { flushPromises, shallowMount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'

import App from '../App.vue'

const mocks = vi.hoisted(() => ({
  loadCurrentUser: vi.fn(),
  logout: vi.fn(() => Promise.resolve()),
  replace: vi.fn(() => Promise.resolve()),
  route: {
    name: 'watchlists',
    fullPath: '/watchlists?watchlist=7',
    meta: { requiresAuth: true },
  },
}))

vi.mock('../composables/useAuth', async () => {
  const { ref } = await import('vue')
  const user = ref({ name: 'Alex Scout', email: 'alex@example.com', role: 'scout' })

  return {
    useAuth: () => ({
      user,
      loadCurrentUser: mocks.loadCurrentUser,
      logout: mocks.logout,
    }),
  }
})

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ replace: mocks.replace }),
}))

describe('App', () => {
  it('leaves a protected route immediately when the user signs out', async () => {
    const wrapper = shallowMount(App, {
      global: {
        stubs: {
          RouterLink: true,
          RouterView: true,
        },
      },
    })

    await wrapper.get('.app-account__trigger').trigger('click')
    await wrapper.get('[role="menuitem"]').trigger('click')
    await flushPromises()

    expect(mocks.logout).toHaveBeenCalledOnce()
    expect(mocks.replace).toHaveBeenCalledWith({
      name: 'login',
      query: { redirect: '/watchlists?watchlist=7' },
    })
  })
})

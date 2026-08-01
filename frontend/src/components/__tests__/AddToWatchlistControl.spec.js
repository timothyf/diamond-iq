import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import AddToWatchlistControl from '../AddToWatchlistControl.vue'
import { USER_TOKEN_STORAGE_KEY } from '../../composables/apiAuth'
import { useAuth } from '../../composables/useAuth'

function response(payload, status = 200) {
  return Promise.resolve({
    ok: status >= 200 && status < 300,
    status,
    json: async () => payload,
  })
}

function mountControl() {
  return mount(AddToWatchlistControl, {
    props: { playerId: 42, playerName: 'Riley Greene' },
    global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
  })
}

describe('AddToWatchlistControl', () => {
  beforeEach(async () => {
    const storage = new Map()
    vi.stubGlobal('localStorage', {
      getItem: (key) => storage.get(key) || null,
      setItem: (key, value) => storage.set(key, String(value)),
      removeItem: (key) => storage.delete(key),
    })
    await useAuth().logout()
  })

  afterEach(async () => {
    localStorage.removeItem(USER_TOKEN_STORAGE_KEY)
    await useAuth().logout()
    vi.unstubAllGlobals()
  })

  it('does not offer watchlist actions to signed-out users', () => {
    const wrapper = mountControl()

    expect(wrapper.find('[data-test="add-to-watchlist-control"]').exists()).toBe(false)
  })

  it('adds the current player to an accessible watchlist', async () => {
    vi.stubGlobal('fetch', vi.fn((url, options = {}) => {
      if (url === '/api/auth/login') {
        return response({ data: { id: 4, token: 'token', name: 'Alex Scout', role: 'scout' } })
      }
      if (url === '/api/watchlists') {
        return response({ data: [{ id: 7, name: 'Trade targets', entries: [] }] })
      }
      if (url === '/api/watchlists/7/watchlist_entries' && options.method === 'POST') {
        return response({ data: { id: 81, player: { id: 42, full_name: 'Riley Greene' } } }, 201)
      }
      return response({ message: 'Not found' }, 404)
    }))
    await useAuth().login('alex@example.com', 'password123')

    const wrapper = mountControl()
    await flushPromises()
    await wrapper.get('.watchlist-control__trigger').trigger('click')
    await flushPromises()
    await wrapper.get('[data-test="watchlist-select"]').setValue('7')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    const createCall = fetch.mock.calls.find(([url, options]) => (
      url === '/api/watchlists/7/watchlist_entries' && options.method === 'POST'
    ))
    expect(createCall[1].headers).toMatchObject({ Authorization: 'Bearer token' })
    expect(JSON.parse(createCall[1].body)).toEqual({ player_id: 42 })
    expect(wrapper.get('[role="status"]').text()).toBe('Riley Greene added to Trade targets.')
    expect(wrapper.text()).toContain('already on every accessible watchlist')
  })

  it('identifies watchlists that already contain the player', async () => {
    vi.stubGlobal('fetch', vi.fn((url) => {
      if (url === '/api/auth/login') {
        return response({ data: { id: 4, token: 'token', name: 'Alex Scout', role: 'scout' } })
      }
      if (url === '/api/watchlists') {
        return response({
          data: [{ id: 7, name: 'Trade targets', entries: [{ id: 81, player: { id: 42 } }] }],
        })
      }
      return response({ message: 'Not found' }, 404)
    }))
    await useAuth().login('alex@example.com', 'password123')

    const wrapper = mountControl()
    await flushPromises()
    await wrapper.get('.watchlist-control__trigger').trigger('click')
    await flushPromises()

    expect(wrapper.find('[data-test="watchlist-select"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('Riley Greene is already on every accessible watchlist.')
  })

  it('shows an API error when adding the player fails', async () => {
    vi.stubGlobal('fetch', vi.fn((url, options = {}) => {
      if (url === '/api/auth/login') {
        return response({ data: { id: 4, token: 'token', name: 'Alex Scout', role: 'scout' } })
      }
      if (url === '/api/watchlists') {
        return response({ data: [{ id: 7, name: 'Trade targets', entries: [] }] })
      }
      if (url === '/api/watchlists/7/watchlist_entries' && options.method === 'POST') {
        return response({ message: 'Player has already been taken' }, 422)
      }
      return response({ message: 'Not found' }, 404)
    }))
    await useAuth().login('alex@example.com', 'password123')

    const wrapper = mountControl()
    await flushPromises()
    await wrapper.get('.watchlist-control__trigger').trigger('click')
    await flushPromises()
    await wrapper.get('[data-test="watchlist-select"]').setValue('7')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(wrapper.get('[role="alert"]').text()).toBe('Player has already been taken')
  })
})

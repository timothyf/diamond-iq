import { flushPromises, mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import NotesPanel from '../NotesPanel.vue'
import { useAuth } from '../../composables/useAuth'

function response(data, status = 200) {
  return Promise.resolve({
    ok: status >= 200 && status < 300,
    status,
    json: async () => ({ data }),
  })
}

describe('NotesPanel', () => {
  beforeEach(async () => {
    const storage = new Map()
    vi.stubGlobal('localStorage', {
      getItem: (key) => storage.get(key) || null,
      setItem: (key, value) => storage.set(key, String(value)),
      removeItem: (key) => storage.delete(key),
    })
    vi.stubGlobal('fetch', vi.fn((url, options = {}) => {
      if (url === '/api/auth/login') {
        return response({ id: 4, token: 'token', name: 'Alex Scout', role: 'scout' })
      }
      if (url === '/api/tags') return response([{ id: 2, name: 'mechanics', color: '#20543c' }])
      if (url.startsWith('/api/notes?')) {
        return response([{
          id: 10,
          target_type: 'player',
          target_id: '7',
          body: 'Watch the release point.',
          note_date: '2026-07-29',
          tags: [{ id: 2, name: 'mechanics', color: '#20543c' }],
          author: { id: 4, name: 'Alex Scout', role: 'scout' },
          last_edited_by: { id: 4, name: 'Alex Scout', role: 'scout' },
          editable: true,
          history_count: 1,
          created_at: '2026-07-29T12:00:00Z',
          updated_at: '2026-07-29T12:00:00Z',
        }])
      }
      if (url === '/api/notes' && options.method === 'POST') {
        return response({
          id: 11,
          target_type: 'player',
          target_id: '7',
          body: 'New observation.',
          note_date: '2026-07-29',
          tags: [],
          author: { id: 4, name: 'Alex Scout', role: 'scout' },
          last_edited_by: { id: 4, name: 'Alex Scout', role: 'scout' },
          editable: true,
          history_count: 1,
        }, 201)
      }
      return response({}, 404)
    }))
    await useAuth().login('alex@example.com', 'password123')
  })

  it('loads attributed notes and reusable tags', async () => {
    const wrapper = mount(NotesPanel, {
      props: { targetType: 'player', targetId: 7, title: 'Player notes' },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Watch the release point.')
    expect(wrapper.text()).toContain('Alex Scout')
    expect(wrapper.text()).toContain('mechanics')
    expect(wrapper.find('option[value="mechanics"]').exists()).toBe(true)
  })

  it('adds a note to the current target', async () => {
    const wrapper = mount(NotesPanel, {
      props: { targetType: 'player', targetId: 7, title: 'Player notes' },
    })
    await flushPromises()
    await wrapper.get('.note-form textarea').setValue('New observation.')
    await wrapper.get('.note-form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('New observation.')
    const createCall = fetch.mock.calls.find(([url, options]) => url === '/api/notes' && options.method === 'POST')
    expect(JSON.parse(createCall[1].body)).toMatchObject({
      target_type: 'player',
      target_id: '7',
      body: 'New observation.',
    })
  })
})

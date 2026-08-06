import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import PlayerSearch from '../PlayerSearch.vue'

const { routerPush } = vi.hoisted(() => ({ routerPush: vi.fn() }))

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: routerPush }),
}))

function playerPayload() {
  return {
    data: [
      {
        id: 1621,
        mlb_id: 592450,
        full_name: 'Aaron Judge',
        team: { abbreviation: 'NYY', name: 'New York Yankees', short_name: 'Yankees' },
      },
      {
        id: 22,
        mlb_id: 110029,
        full_name: 'Aaron Sele',
        team: { abbreviation: 'LAD', name: 'Los Angeles Dodgers', short_name: 'Dodgers' },
      },
    ],
  }
}

function teamPayload() {
  return {
    data: [
      {
        id: 9,
        mlb_id: 147,
        name: 'New York Yankees',
        abbreviation: 'NYY',
        location_name: 'New York',
      },
    ],
  }
}

describe('PlayerSearch', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    routerPush.mockReset()
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('normalizes input and renders autocomplete results after a debounce', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => playerPayload() })
      .mockResolvedValueOnce({ ok: true, json: async () => teamPayload() })
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('  Judge,    Aaron  ')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(2)
    const requestUrl = new URL(fetchMock.mock.calls[0][0], 'http://diamondiq.test')
    expect(requestUrl.searchParams.get('filter[name]')).toBe('Judge Aaron')
    expect(requestUrl.searchParams.get('per_page')).toBe('8')
    expect(wrapper.text()).toContain('Aaron Judge')
    expect(wrapper.text()).toContain('Yankees')
  })

  it('does not search until at least two normalized characters are present', async () => {
    const fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue(' % A ')
    await vi.advanceTimersByTimeAsync(300)

    expect(fetchMock).not.toHaveBeenCalled()
    expect(wrapper.find('[role="listbox"]').exists()).toBe(false)
  })

  it('supports keyboard selection and navigates to the selected profile', async () => {
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => playerPayload() })
      .mockResolvedValueOnce({ ok: true, json: async () => teamPayload() }))
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('aaron')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    await wrapper.get('input').trigger('keydown', { key: 'ArrowDown' })
    await wrapper.get('input').trigger('keydown', { key: 'Enter' })
    await flushPromises()

    expect(routerPush).toHaveBeenCalledWith({ name: 'player-profile', params: { id: '22' } })
  })

  it('finds teams and navigates to the selected team profile', async () => {
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: [] }) })
      .mockResolvedValueOnce({ ok: true, json: async () => teamPayload() }))
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('yankees')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    await wrapper.get('button').trigger('click')
    await flushPromises()

    expect(routerPush).toHaveBeenCalledWith({ name: 'team-profile', params: { id: '9' } })
  })

  it('ignores a stale response after the query changes', async () => {
    let resolveFirstPlayers
    let resolveFirstTeams
    let resolveSecondPlayers
    let resolveSecondTeams
    const fetchMock = vi.fn()
      .mockImplementationOnce(() => new Promise((resolve) => { resolveFirstPlayers = resolve }))
      .mockImplementationOnce(() => new Promise((resolve) => { resolveFirstTeams = resolve }))
      .mockImplementationOnce(() => new Promise((resolve) => { resolveSecondPlayers = resolve }))
      .mockImplementationOnce(() => new Promise((resolve) => { resolveSecondTeams = resolve }))
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('aaron')
    await vi.advanceTimersByTimeAsync(250)
    await wrapper.get('input').setValue('shohei')
    await vi.advanceTimersByTimeAsync(250)

    resolveSecondPlayers({
      ok: true,
      json: async () => ({ data: [{ id: 99, mlb_id: 660271, full_name: 'Shohei Ohtani', team: null }] }),
    })
    resolveSecondTeams({ ok: true, json: async () => ({ data: [] }) })
    await flushPromises()
    expect(wrapper.text()).toContain('Shohei Ohtani')

    resolveFirstPlayers({ ok: true, json: async () => playerPayload() })
    resolveFirstTeams({ ok: true, json: async () => teamPayload() })
    await flushPromises()
    expect(wrapper.text()).toContain('Shohei Ohtani')
    expect(wrapper.text()).not.toContain('Aaron Judge')
  })

  it('shows empty and failure states without throwing on malformed responses', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: null }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: [] }) })
      .mockResolvedValueOnce({ ok: false, status: 500 })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: [] }) })
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('nobody')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    expect(wrapper.text()).toContain('No players or teams found')

    await wrapper.get('input').setValue('somebody')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    expect(wrapper.text()).toContain('temporarily unavailable')
  })
})

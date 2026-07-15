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
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => playerPayload() })
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('  Judge,    Aaron  ')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(1)
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
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => playerPayload() }))
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('aaron')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    await wrapper.get('input').trigger('keydown', { key: 'ArrowDown' })
    await wrapper.get('input').trigger('keydown', { key: 'Enter' })
    await flushPromises()

    expect(routerPush).toHaveBeenCalledWith({ name: 'player-profile', params: { id: '22' } })
  })

  it('ignores a stale response after the query changes', async () => {
    let resolveFirst
    let resolveSecond
    const fetchMock = vi.fn()
      .mockImplementationOnce(() => new Promise((resolve) => { resolveFirst = resolve }))
      .mockImplementationOnce(() => new Promise((resolve) => { resolveSecond = resolve }))
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('aaron')
    await vi.advanceTimersByTimeAsync(250)
    await wrapper.get('input').setValue('shohei')
    await vi.advanceTimersByTimeAsync(250)

    resolveSecond({
      ok: true,
      json: async () => ({ data: [{ id: 99, mlb_id: 660271, full_name: 'Shohei Ohtani', team: null }] }),
    })
    await flushPromises()
    expect(wrapper.text()).toContain('Shohei Ohtani')

    resolveFirst({ ok: true, json: async () => playerPayload() })
    await flushPromises()
    expect(wrapper.text()).toContain('Shohei Ohtani')
    expect(wrapper.text()).not.toContain('Aaron Judge')
  })

  it('shows empty and failure states without throwing on malformed responses', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: null }) })
      .mockResolvedValueOnce({ ok: false, status: 500 })
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(PlayerSearch)

    await wrapper.get('input').setValue('nobody')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    expect(wrapper.text()).toContain('No players found')

    await wrapper.get('input').setValue('somebody')
    await vi.advanceTimersByTimeAsync(250)
    await flushPromises()
    expect(wrapper.text()).toContain('temporarily unavailable')
  })
})

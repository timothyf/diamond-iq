import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import WatchlistsView from '../WatchlistsView.vue'

const RouterLinkStub = { name: 'RouterLink', props: ['to'], template: '<a><slot /></a>' }

describe('WatchlistsView', () => {
  it('shows acquisition evaluation controls for watched players', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [{
          id: 9, name: 'Trade targets', description: 'Deadline candidates', entries: [{
            id: 41, priority: 'high', status: 'active', recommendation: 'pursue',
            fit_score: 5, need_score: 4, cost_score: 3, risk_score: 2, tags: ['power'], notes: 'Fits the middle of the order.',
            player: { id: 42, mlb_id: 680776, full_name: 'Riley Greene', team: { name: 'Detroit Tigers', abbreviation: 'DET' } },
          }],
        }],
      }),
    }))

    const wrapper = mount(WatchlistsView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()

    expect(wrapper.text()).toContain('Trade targets')
    expect(wrapper.text()).toContain('Riley Greene')
    expect(wrapper.text()).toContain('Recommendation')
    expect(wrapper.get('textarea').element.value).toBe('Fits the middle of the order.')
    expect(wrapper.getComponent('.evaluation-card a').props('to')).toEqual({ name: 'player-profile', params: { id: 42 } })
  })
})

import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import WatchlistsView from '../WatchlistsView.vue'

const RouterLinkStub = { name: 'RouterLink', props: ['to'], template: '<a><slot /></a>' }

describe('WatchlistsView', () => {
  it('shows acquisition evaluation controls for watched players', async () => {
    vi.stubGlobal('fetch', vi.fn().mockImplementation((url) => {
      const data = url === '/api/watchlists'
        ? [{
          id: 9, name: 'Trade targets', description: 'Deadline candidates', entries: [{
            id: 41, priority: 'high', status: 'active', recommendation: 'pursue',
            fit_score: 5, need_score: 4, cost_score: 3, risk_score: 2, tags: ['power'], notes: 'Fits the middle of the order.',
            player: { id: 42, mlb_id: 680776, full_name: 'Riley Greene', team: { name: 'Detroit Tigers', abbreviation: 'DET' } },
          }],
        }]
        : []
      return Promise.resolve({ ok: true, json: async () => ({ data }) })
    }))

    const wrapper = mount(WatchlistsView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()

    expect(wrapper.text()).toContain('Trade targets')
    expect(wrapper.text()).toContain('Riley Greene')
    expect(wrapper.text()).toContain('Recommendation')
    expect(wrapper.get('[data-test="review-status-select"]').findAll('option')).toHaveLength(7)
    expect(wrapper.get('[data-test="evaluation-notes"]').element.value).toBe('Fits the middle of the order.')
    expect(wrapper.getComponent('.evaluation-card a').props('to')).toEqual({ name: 'player-profile', params: { id: 42 } })
  })

  it('shows calculated fit, ranked discovery, and similar alternatives', async () => {
    const needProfile = {
      id: 3,
      name: 'Left-handed impact outfielder',
      description: 'Deadline lineup need',
      team: { id: 1, name: 'Detroit Tigers', abbreviation: 'DET' },
      weights: { position: 20, handedness: 15, age: 10, performance: 55 },
    }
    const candidate = {
      calculated_fit_score: 96.4,
      fit_breakdown: { components: { position: { score: 100 }, performance: { score: 93.5 } } },
      player: { id: 84, full_name: 'External Candidate', age: 27, position: { abbreviation: 'RF' }, team: { abbreviation: 'SEA' } },
    }
    const alternative = {
      ...candidate,
      alternative_score: 91.2,
      similarity_score: 88.0,
      player: { ...candidate.player, id: 85, full_name: 'Similar Alternative', team: { abbreviation: 'BAL' } },
    }
    const fetchMock = vi.fn().mockImplementation((url) => {
      let data = []
      if (url === '/api/watchlists') {
        data = [{
          id: 9,
          name: 'Trade targets',
          description: 'Deadline candidates',
          need_profile: needProfile,
          entries: [{
            id: 41,
            priority: 'high',
            status: 'active',
            recommendation: 'pursue',
            calculated_fit_score: 94.2,
            fit_breakdown: {
              components: {
                position: { score: 100 },
                handedness: { score: 100 },
                age: { score: 85 },
                performance: { score: 92.4 },
              },
            },
            tags: [],
            player: { id: 42, full_name: 'Riley Greene', team: { name: 'Detroit Tigers', abbreviation: 'DET' } },
          }],
        }]
      } else if (url === '/api/need_profiles') {
        data = [needProfile]
      } else if (url.startsWith('/api/watchlists/9/discovery')) {
        data = [candidate]
      } else if (url === '/api/watchlist_entries/41/alternatives') {
        data = [alternative]
      }
      return Promise.resolve({ ok: true, json: async () => ({ data }) })
    })
    vi.stubGlobal('fetch', fetchMock)

    const wrapper = mount(WatchlistsView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()

    expect(wrapper.get('[data-test="need-workspace"]').text()).toContain('Left-handed impact outfielder')
    expect(wrapper.get('[data-test="calculated-fit"]').text()).toContain('94.2')
    expect(wrapper.get('[data-test="calculated-fit"]').text()).toContain('Performance')

    await wrapper.get('.discovery-filters').trigger('submit')
    await flushPromises()
    expect(wrapper.get('[data-test="candidate-discovery"]').text()).toContain('External Candidate')
    expect(wrapper.get('[data-test="candidate-discovery"]').text()).toContain('96.4')

    await wrapper.get('.secondary-action').trigger('click')
    await flushPromises()
    expect(wrapper.get('[data-test="similar-alternatives"]').text()).toContain('Similar Alternative')
    expect(wrapper.get('[data-test="similar-alternatives"]').text()).toContain('similarity 88.0')
  })
})

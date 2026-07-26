import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import LineupScenarioView from '../LineupScenarioView.vue'

const RouterLinkStub = { name: 'RouterLink', props: ['to'], template: '<a><slot /></a>' }

describe('LineupScenarioView', () => {
  it('renders a validated lineup in batting order', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: {
          id: 401, team_id: 1, name: 'Vs RHP — opener', scenario_date: '2026-07-16', notes: 'Attack early.',
          entries: [
            { id: 1, batting_slot: 1, defensive_position: 'CF', player: { id: 42, full_name: 'Riley Greene' } },
            { id: 2, batting_slot: 2, defensive_position: 'DH', player: { id: 43, full_name: 'Kerry Carpenter' } },
          ],
        },
      }),
    }))

    const wrapper = mount(LineupScenarioView, {
      props: { scenarioId: '401' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('constraint validated')
    expect(wrapper.text()).toContain('Riley Greene')
    expect(wrapper.text()).toContain('Attack early.')
    expect(wrapper.getComponent('tbody a').props('to')).toEqual({ name: 'player-profile', params: { id: 42 } })
  })
})

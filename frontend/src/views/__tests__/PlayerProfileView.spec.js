import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import PlayerProfileView from '../PlayerProfileView.vue'

function apiPayload() {
  return {
    data: {
      id: 42,
      mlb_id: 680776,
      first_name: 'Riley',
      last_name: 'Greene',
      full_name: 'Riley Greene',
      team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
      profile: {
        age: 25,
        birth_date: '2000-09-28',
        formatted_height: `6' 3"`,
        weight_pounds: 200,
        bats: 'L',
        throws: 'L',
        mlb_debut_date: '2022-06-18',
      },
      positions: {
        primary: { abbreviation: 'CF', name: 'Outfielder' },
        secondary: [],
        assignments: [],
      },
      season_overview: {
        season: 2026,
        category: 'batting',
        preferred_category: 'batting',
        stats: [
          { key: 'homeRuns', label: 'HR', value: '18.0', scope_key: 'DET' },
          { key: 'ops', label: 'OPS', value: '0.842', scope_key: 'DET' },
        ],
      },
      current_membership: {
        id: 8,
        team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
        starts_on: '2026-03-26',
        roster_status: 'active',
        source_status_description: 'Active',
        jersey_number: '31',
      },
      team_history: [
        {
          id: 8,
          team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
          starts_on: '2026-03-26',
          roster_status: 'active',
          source_status_description: 'Active',
        },
      ],
      recent_pitch_indicators: {
        sample_size: 100,
        primary_role: 'batter',
        batting: {
          pitches_seen: 100,
          game_count: 8,
          batted_ball_count: 22,
          average_exit_velocity: 91.2,
          max_exit_velocity: 109.5,
          hard_hit_percentage: 45.5,
        },
        pitching: { pitch_count: 0, game_count: 0 },
      },
      source_metadata: {
        last_updated_at: '2026-07-14T12:00:00Z',
        sources: ['MLB Stats API', 'Baseball Savant'],
        datasets: [
          { name: 'profile', source_name: 'MLB Stats API', last_updated_at: '2026-07-14T12:00:00Z' },
          { name: 'pitch_data', source_name: 'Baseball Savant', last_updated_at: '2026-07-14T11:00:00Z' },
        ],
      },
    },
  }
}

describe('PlayerProfileView', () => {
  it('renders the unified player workflow', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayload(),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: {
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
        },
      },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Riley Greene')
    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('Active')
    expect(wrapper.text()).toContain('2026 Batting')
    expect(wrapper.text()).toContain('18.0')
    expect(wrapper.text()).toContain('Recent pitch indicators')
    expect(wrapper.text()).toContain('91.2 mph')
    expect(wrapper.text()).toContain('Team history')
    expect(wrapper.text()).toContain('Baseball Savant')
  })

  it('renders a retry state when loading fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="profile-error"]').text()).toContain('Unable to load this player profile')
    expect(wrapper.get('button').text()).toBe('Try again')
  })
})

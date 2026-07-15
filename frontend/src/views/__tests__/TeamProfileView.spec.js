import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import TeamProfileView from '../TeamProfileView.vue'

const payload = {
  data: {
    id: 1,
    mlb_id: 116,
    name: 'Detroit Tigers',
    abbreviation: 'DET',
    team_name: 'Tigers',
    location_name: 'Detroit',
    short_name: 'Detroit',
    logo_url: 'https://www.mlbstatic.com/team-logos/116.svg',
    season: 2026,
    available_seasons: [2025, 2026],
    record: { wins: 52, losses: 43, ties: 0, games_played: 95, runs_scored: 430, runs_allowed: 401 },
    roster_summary: { total: 40, active: 26, injured: 6, other: 8 },
    roster: [
      {
        id: 9,
        roster_status: 'active',
        status_description: 'Active',
        injured: false,
        jersey_number: '31',
        primary_position: 'CF',
        starts_on: '2026-03-26',
        player: { id: 42, mlb_id: 680776, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null },
      },
    ],
    recent_games: [
      { id: 80, official_date: '2026-07-14', home_score: 5, away_score: 2, home_team: { id: 1, abbreviation: 'DET' }, away_team: { id: 2, abbreviation: 'CLE' } },
    ],
    upcoming_games: [
      { id: 81, official_date: '2026-07-16', venue_name: 'Comerica Park', home_score: null, away_score: null, home_team: { id: 1, abbreviation: 'DET' }, away_team: { id: 2, abbreviation: 'CLE' }, home_probable_pitcher: { full_name: 'Tarik Skubal' } },
    ],
    source_metadata: { last_updated_at: '2026-07-15T12:00:00Z', schedule_last_synced_at: '2026-07-15T12:00:00Z', roster_last_synced_at: '2026-07-15T11:00:00Z', sources: ['MLB Stats API'] },
  },
}

describe('TeamProfileView', () => {
  it('renders team identity, record, schedule, and current roster', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('52–43')
    expect(wrapper.get('[data-test="upcoming-games"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="recent-games"]').text()).toContain('5–2')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('CF')
    expect(wrapper.get('[data-test="team-season-select"]').text()).toContain('2025')
  })

  it('renders a retry state when the profile cannot load', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="team-error"]').text()).toContain('Unable to load this team profile')
  })
})

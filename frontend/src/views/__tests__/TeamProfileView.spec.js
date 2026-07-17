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
    roster_as_of: '2026-07-15',
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
      {
        id: 10,
        roster_status: 'minors',
        status_description: 'Minors',
        injured: false,
        jersey_number: '20',
        primary_position: '1B',
        starts_on: '2026-06-01',
        player: { id: 43, mlb_id: 679529, full_name: 'Spencer Torkelson', first_name: 'Spencer', last_name: 'Torkelson', headshot_url: null },
      },
    ],
    rosters: {
      forty_man: [
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
        {
          id: 10,
          roster_status: 'minors',
          status_description: 'Minors',
          injured: false,
          jersey_number: '20',
          primary_position: '1B',
          starts_on: '2026-06-01',
          player: { id: 43, mlb_id: 679529, full_name: 'Spencer Torkelson', first_name: 'Spencer', last_name: 'Torkelson', headshot_url: null },
        },
      ],
      active: [
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
    },
    recent_games: [
      { id: 80, official_date: '2026-07-14', home_score: 5, away_score: 2, home_team: { id: 1, abbreviation: 'DET' }, away_team: { id: 2, abbreviation: 'CLE' } },
    ],
    upcoming_games: [
      { id: 81, official_date: '2026-07-16', venue_name: 'Comerica Park', home_score: null, away_score: null, home_team: { id: 1, abbreviation: 'DET' }, away_team: { id: 2, abbreviation: 'CLE' }, home_probable_pitcher: { full_name: 'Tarik Skubal' } },
    ],
    source_metadata: { last_updated_at: '2026-07-15T12:00:00Z', schedule_last_synced_at: '2026-07-15T12:00:00Z', roster_last_synced_at: '2026-07-15T11:00:00Z', sources: ['MLB Stats API'] },
    performance_dashboard: {
      rankings: {
        offense: {
          ops: { rank: 5, value: 0.765 },
          runs_per_game: { rank: 8, value: 4.5 },
          strikeout_rate: { rank: 12, value: 0.219 },
          walk_rate: { rank: 9, value: 0.086 },
        },
        pitching: {
          era: { rank: 7, value: 3.8126 },
          whip: { rank: 10, value: 1.2346 },
          strikeout_rate: { rank: 6, value: 0.251 },
          walk_rate: { rank: 11, value: 0.082 },
        },
        context: { total_teams: 30 },
      },
      recent_form: {
        '7': { wins: 5, losses: 2, ops: 0.791, era: 3.43 },
        '15': { wins: 9, losses: 6, ops: 0.768, era: 3.76 },
        '30': { wins: 17, losses: 13, ops: 0.751, era: 3.92 },
      },
      home_road_splits: {
        home: { wins: 27, losses: 19, run_differential: 22 },
        road: { wins: 25, losses: 24, run_differential: 7 },
      },
      platoon_splits: {
        offense: {
          vs_left: { strikeout_rate: 0.244, average_exit_velocity: 90.2 },
          vs_right: { strikeout_rate: 0.211, average_exit_velocity: 91.0 },
        },
        pitching: {
          vs_left: { strikeout_rate: 0.257, average_velocity: 94.1 },
          vs_right: { strikeout_rate: 0.245, average_velocity: 94.4 },
        },
      },
      starter_bullpen: {
        starters: { innings_pitched: 520.1, era: 3.61, whip: 1.18 },
        bullpen: { innings_pitched: 336.2, era: 4.13, whip: 1.31 },
      },
      one_run_performance: { wins: 14, losses: 11, games: 25, winning_percentage: 0.56 },
      analytics_coverage: {
        complete: true,
        completed_game_count: 95,
        complete_pitching_game_count: 95,
        missing_game_count: 0,
        missing_games: [],
      },
      strengths: ['Top-10 offense by OPS'],
      concerns: ['Offense has cooled over the last 30 games'],
      drill_down: {
        games: [
          { id: 80, official_date: '2026-07-14', result: 'W', opponent: 'CLE', score: { team: 5, opponent: 2 } },
        ],
        players: {
          hitters: [
            { player: { id: 42, full_name: 'Riley Greene' }, ops: 0.842 },
          ],
          pitchers: [],
        },
        plate_appearances: {
          team_total: 3812,
          leaders: [
            { player: { id: 42, full_name: 'Riley Greene' }, plate_appearances: 421 },
          ],
        },
        pitches: {
          team_total: 14280,
          leaders: [
            { player: { id: 51, full_name: 'Tarik Skubal' }, pitches: 1788 },
          ],
        },
      },
    },
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
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="roster-view-40man"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="roster-view-40man"]').text()).toContain('2')
    expect(wrapper.get('[data-test="roster-view-active"]').text()).toContain('1')

    await wrapper.get('[data-test="roster-view-active"]').trigger('click')

    expect(wrapper.get('[data-test="roster-view-active"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="team-roster"]').text()).not.toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="team-season-select"]').text()).toContain('2025')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Team performance dashboard')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Last 7 games')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('#7 · 3.81')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('#10 · 1.23')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Top-10 offense by OPS')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Total tracked pitches: 14280')
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

  it('warns when completed games are missing pitching details', async () => {
    const incompletePayload = structuredClone(payload)
    incompletePayload.data.performance_dashboard.analytics_coverage = {
      complete: false,
      completed_game_count: 96,
      complete_pitching_game_count: 95,
      missing_game_count: 1,
      missing_games: [{ mlb_id: 823632, official_date: '2026-05-12', matchup: 'DET at NYM' }],
    }
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => incompletePayload }))

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="analytics-coverage-warning"]').text()).toContain('1 of 96 completed games is missing pitching details')
  })
})

import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import TeamProfileView from '../TeamProfileView.vue'

const RouterLinkStub = {
  name: 'RouterLink',
  props: ['to'],
  template: '<a><slot /></a>',
}

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
        roster_status: 'injured_10_day',
        status_description: '10-Day Injured List',
        injured: true,
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
          roster_status: 'injured_10_day',
          status_description: '10-Day Injured List',
          injured: true,
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
    team_leaders: {
      batting: [
        { key: 'avg', label: 'Batting average', abbreviation: 'AVG', value: '0.287', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
        { key: 'ops', label: 'On-base plus slugging', abbreviation: 'OPS', value: '0.842', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
        { key: 'homeRuns', label: 'Home runs', abbreviation: 'HR', value: '24', player: { id: 43, full_name: 'Spencer Torkelson', first_name: 'Spencer', last_name: 'Torkelson', headshot_url: null } },
        { key: 'rbi', label: 'Runs batted in', abbreviation: 'RBI', value: '68', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
      ],
      pitching: [
        { key: 'W', label: 'Wins', abbreviation: 'W', value: '11', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'ERA', label: 'Earned run average', abbreviation: 'ERA', value: '2.01', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'whip', label: 'Walks and hits per inning', abbreviation: 'WHIP', value: '0.99', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'strikeOuts', label: 'Strikeouts', abbreviation: 'SO', value: '162', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
      ],
    },
    performance_dashboard: {
      rankings: {
        offense: {
          ops: { rank: 5, value: 0.765 },
          runs_per_game: { rank: 8, value: 4.5 },
          home_runs: { rank: 6, value: 132 },
          batting_average: { rank: 7, value: 0.261 },
          stolen_bases: { rank: 11, value: 68 },
          strikeout_rate: { rank: 12, value: 0.219 },
          walk_rate: { rank: 9, value: 0.086 },
        },
        pitching: {
          era: { rank: 7, value: 3.8126 },
          whip: { rank: 10, value: 1.2346 },
          saves: { rank: 4, value: 31 },
          strikeouts: { rank: 3, value: 902 },
          quality_starts: { rank: 8, value: 44 },
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
  it('renders the overview and opens a separate roster tab on the active roster', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('52–43')
    expect(wrapper.get('[data-test="upcoming-games"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="recent-games"]').text()).toContain('5–2')
    expect(wrapper.get('[data-test="recent-games"] .game-result-link').exists()).toBe(true)
    expect(wrapper.get('[data-test="team-profile-tab-overview"]').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('[data-test="team-profile-panel-overview"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-roster"]').attributes('style')).toContain('display: none')

    await wrapper.get('[data-test="team-profile-tab-roster"]').trigger('click')

    expect(wrapper.get('[data-test="team-profile-tab-roster"]').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('[data-test="team-profile-panel-overview"]').attributes('style')).toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-roster"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('CF')
    expect(wrapper.get('[data-test="team-roster"]').text()).not.toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="roster-view-active"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="roster-view-40man"]').text()).toContain('2')
    expect(wrapper.get('[data-test="roster-view-active"]').text()).toContain('1')
    expect(wrapper.get('[data-test="roster-view-injured"]').text()).toContain('1')

    await wrapper.get('[data-test="roster-view-injured"]').trigger('click')

    expect(wrapper.get('[data-test="roster-view-injured"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('10-Day Injured List')
    expect(wrapper.get('[data-test="team-roster"]').text()).not.toContain('Riley Greene')

    await wrapper.get('[data-test="roster-view-40man"]').trigger('click')

    expect(wrapper.get('[data-test="roster-view-40man"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="team-season-select"]').text()).toContain('2025')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Team performance dashboard')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Last 7 games')
    expect(wrapper.get('[data-test="pitching-ranking-era"]').text()).toContain('3.81')
    expect(wrapper.get('[data-test="pitching-ranking-era"]').text()).toContain('#7')
    expect(wrapper.get('[data-test="pitching-ranking-whip"]').text()).toContain('1.23')
    expect(wrapper.get('[data-test="pitching-ranking-whip"]').text()).toContain('#10')
    expect(wrapper.get('[data-test="pitching-ranking-saves"]').text()).toContain('31')
    expect(wrapper.get('[data-test="pitching-ranking-strikeouts"]').text()).toContain('902')
    expect(wrapper.get('[data-test="pitching-ranking-quality-starts"]').text()).toContain('44')
    expect(wrapper.get('[data-test="offense-ranking-home-runs"]').text()).toContain('132')
    expect(wrapper.get('[data-test="offense-ranking-home-runs"]').text()).toContain('#6')
    expect(wrapper.get('[data-test="offense-ranking-batting-average"]').text()).toContain('0.261')
    expect(wrapper.get('[data-test="offense-ranking-batting-average"]').text()).toContain('#7')
    expect(wrapper.get('[data-test="offense-ranking-stolen-bases"]').text()).toContain('68')
    expect(wrapper.get('[data-test="offense-ranking-stolen-bases"]').text()).toContain('#11')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Top-10 offense by OPS')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Total tracked pitches: 14280')
    expect(wrapper.getComponent('[data-test="plate-appearance-player-42"]').props('to')).toEqual({
      name: 'player-profile',
      params: { id: 42 },
    })
    expect(wrapper.getComponent('[data-test="pitch-player-51"]').props('to')).toEqual({
      name: 'player-profile',
      params: { id: 51 },
    })
    const leaders = wrapper.get('[data-test="team-leaders"]')
    expect(leaders.text()).toContain('Team leaders')
    expect(leaders.text()).toContain('Riley Greene')
    expect(leaders.text()).toContain('.287')
    expect(leaders.text()).toContain('Spencer Torkelson')
    expect(leaders.text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="team-leader-ERA"]').text()).toContain('2.01')
    expect(wrapper.get('[data-test="team-leader-ops"]').text()).toContain('.842')
    expect(wrapper.get('[data-test="team-leader-whip"]').text()).toContain('0.99')
  })

  it('sizes ranking bars from empty to full using the 30-team comparison', async () => {
    const rankingPayload = structuredClone(payload)
    rankingPayload.data.performance_dashboard.rankings.offense.ops.rank = 1
    rankingPayload.data.performance_dashboard.rankings.offense.runs_per_game.rank = 0
    rankingPayload.data.performance_dashboard.rankings.offense.strikeout_rate.rank = 15
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => rankingPayload }))

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    const first = wrapper.get('[data-test="offense-ranking-ops"]')
    const unavailable = wrapper.get('[data-test="offense-ranking-runs-per-game"]')
    const middle = wrapper.get('[data-test="offense-ranking-strikeout-rate"]')

    expect(first.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('100')
    expect(first.get('.ranking-bar__fill').attributes('style')).toContain('width: 100%')
    expect(unavailable.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('0')
    expect(unavailable.get('.ranking-bar__fill').attributes('style')).toContain('width: 0%')
    expect(middle.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('50')
    expect(middle.get('.ranking-bar__fill').attributes('style')).toContain('width: 50%')
  })

  it('reloads the profile for the selected season', async () => {
    const historicalPayload = structuredClone(payload)
    historicalPayload.data.season = 2025
    historicalPayload.data.record = {
      wins: 82,
      losses: 80,
      ties: 0,
      games_played: 162,
      runs_scored: 682,
      runs_allowed: 667,
    }
    historicalPayload.data.performance_dashboard.rankings.offense.ops.value = 0.699

    const fetchMock = vi.fn().mockImplementation(async (url) => ({
      ok: true,
      json: async () => (String(url).includes('season=2025') ? historicalPayload : payload),
    }))
    vi.stubGlobal('fetch', fetchMock)

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="team-season-select"]').setValue('2025')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/teams/1?season=2025'),
      expect.any(Object),
    )
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('2025 record')
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('82–80')
    expect(wrapper.get('[data-test="offense-ranking-ops"]').text()).toContain('0.699')
  })

  it('shows a loading indicator while a different season is loading', async () => {
    let resolveHistoricalRequest
    const historicalRequest = new Promise((resolve) => {
      resolveHistoricalRequest = resolve
    })
    const fetchMock = vi.fn().mockImplementation((url) => {
      if (String(url).includes('season=2025')) return historicalRequest

      return Promise.resolve({ ok: true, json: async () => payload })
    })
    vi.stubGlobal('fetch', fetchMock)

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="team-season-select"]').setValue('2025')

    expect(wrapper.get('[data-test="season-loading"]').text()).toContain('Loading 2025 season')
    expect(wrapper.get('[data-test="team-season-select"]').attributes()).toHaveProperty('disabled')
    expect(wrapper.get('.team-profile-shell').attributes('aria-busy')).toBe('true')

    resolveHistoricalRequest({ ok: true, json: async () => payload })
    await flushPromises()

    expect(wrapper.find('[data-test="season-loading"]').exists()).toBe(false)
    expect(wrapper.get('[data-test="team-season-select"]').attributes()).not.toHaveProperty('disabled')
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

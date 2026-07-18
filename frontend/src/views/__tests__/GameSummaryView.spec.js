import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, vi } from 'vitest'

import GameSummaryView from '../GameSummaryView.vue'

const RouterLink = {
  props: ['to'],
  template: '<a href="#"><slot /></a>',
}

const payload = {
  data: {
    id: 80,
    mlb_id: 823443,
    official_date: '2026-07-14',
    scheduled_at: '2026-07-14T23:10:00Z',
    status: 'final',
    detailed_status: 'Final',
    venue_name: 'Comerica Park',
    away_score: 1,
    home_score: 3,
    away_team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians' },
    home_team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
    details: {
      synchronized: true,
      last_synced_at: '2026-07-15T02:30:00Z',
      insights: {
        decisions: {
          winning_pitcher: { player: { id: 23, full_name: 'Tarik Skubal' }, decision: '(W, 11-2)' },
          losing_pitcher: { player: { id: 22, full_name: 'Tanner Bibee' }, decision: '(L, 7-5)' },
          save: { player: { id: 24, full_name: 'Will Vest' }, decision: '(S, 1)' },
        },
        teams: {
          away: { run_differential: -2, hits: 5, errors: 0, walks: 2, strikeouts: 9, home_runs: 0, left_on_base: 6, runners_in_scoring_position: { hits: 1, at_bats: 5 } },
          home: { run_differential: 2, hits: 8, errors: 1, walks: 3, strikeouts: 7, home_runs: 1, left_on_base: 7, runners_in_scoring_position: { hits: 2, at_bats: 6 } },
        },
      },
      key_performers: {
        top_hitters: {
          away: {
            player: { id: 20, full_name: 'Steven Kwan' }, team: { id: 2, abbreviation: 'CLE' },
            summary: '2-for-4, 1 RBI, 1 R', metrics: { hits: 2, total_bases: 3 },
          },
          home: {
            player: { id: 21, full_name: 'Riley Greene' }, team: { id: 1, abbreviation: 'DET' },
            summary: '2-for-4, 1 HR, 3 RBI, 1 R', metrics: { hits: 2, home_runs: 1, total_bases: 5 },
          },
        },
        most_impactful_pitcher: {
          player: { id: 23, full_name: 'Tarik Skubal' }, team: { id: 1, abbreviation: 'DET' },
          summary: '7.0 IP, 1 ER, 9 K, W', metrics: { innings_pitched: '7.0', strikeouts: 9 },
        },
        power_hitters: [
          {
            player: { id: 21, full_name: 'Riley Greene' }, team: { id: 1, abbreviation: 'DET' },
            summary: '1 HR', metrics: { home_runs: 1 },
          },
        ],
        scoreless_relievers: [
          {
            player: { id: 24, full_name: 'Will Vest' }, team: { id: 1, abbreviation: 'DET' },
            summary: '1.0 scoreless IP · 2 K', metrics: { innings_pitched: '1.0', strikeouts: 2 },
          },
        ],
        top_run_producers: [
          {
            player: { id: 21, full_name: 'Riley Greene' }, team: { id: 1, abbreviation: 'DET' },
            summary: '3 runs produced · 1 R, 3 RBI', metrics: { runs_responsible_for: 3 },
          },
        ],
      },
      scoring_plays: [
        {
          id: 101,
          plate_appearance_number: 12,
          inning: 1,
          half_inning: 'top',
          inning_label: 'Top 1st',
          event: 'Single',
          event_type: 'single',
          description: 'Steven Kwan singles, scoring a run.',
          runs_scored: 1,
          runs_batted_in: 1,
          away_score: 1,
          home_score: 0,
          batter: { id: 20, full_name: 'Steven Kwan' },
          batting_team: { id: 2, abbreviation: 'CLE' },
        },
        {
          id: 102,
          plate_appearance_number: 24,
          inning: 2,
          half_inning: 'bottom',
          inning_label: 'Bottom 2nd',
          event: 'Double',
          event_type: 'double',
          description: 'Will Vest doubled, scoring a run.',
          runs_scored: 1,
          runs_batted_in: 1,
          away_score: 1,
          home_score: 1,
          batter: { id: 24, full_name: 'Will Vest' },
          batting_team: { id: 1, abbreviation: 'DET' },
        },
        {
          id: 103,
          plate_appearance_number: 38,
          inning: 4,
          half_inning: 'bottom',
          inning_label: 'Bottom 4th',
          event: 'Home Run',
          event_type: 'home_run',
          description: 'Riley Greene homered, scoring two runs.',
          runs_scored: 2,
          runs_batted_in: 2,
          away_score: 1,
          home_score: 3,
          batter: { id: 21, full_name: 'Riley Greene' },
          batting_team: { id: 1, abbreviation: 'DET' },
        },
      ],
      line_score: {
        current_inning: 9,
        current_inning_ordinal: '9th',
        inning_state: 'End',
        innings: [
          { number: 1, ordinal: '1st', away: { runs: 1 }, home: { runs: 0 } },
          { number: 2, ordinal: '2nd', away: { runs: 0 }, home: { runs: 3 } },
        ],
        totals: {
          away: { runs: 1, hits: 5, errors: 0 },
          home: { runs: 3, hits: 8, errors: 1 },
        },
      },
      batting_lines: [
        {
          id: 1, home: false, player: { id: 20, full_name: 'Steven Kwan' }, position: 'LF',
          at_bats: 4, runs: 1, hits: 2, doubles: 1, triples: 0, home_runs: 0,
          runs_batted_in: 1, walks: 0, strikeouts: 1, batting_average: '0.3010', ops: '0.8120',
        },
        {
          id: 2, home: true, player: { id: 21, full_name: 'Riley Greene' }, position: 'CF',
          at_bats: 4, runs: 1, hits: 2, doubles: 0, triples: 0, home_runs: 1,
          runs_batted_in: 3, walks: 0, strikeouts: 1, batting_average: '0.2870', ops: '0.8420',
        },
      ],
      pitching_lines: [
        {
          id: 3, home: false, player: { id: 22, full_name: 'Tanner Bibee' }, innings_pitched: '6.1',
          hits: 5, runs: 3, earned_runs: 3, walks: 2, strikeouts: 7, home_runs: 1,
          pitches: 91, strikes: 62, era: '3.456', whip: '1.234', decision: 'L (7-5)',
        },
        {
          id: 4, home: true, player: { id: 23, full_name: 'Tarik Skubal' }, innings_pitched: '7.0',
          hits: 4, runs: 1, earned_runs: 1, walks: 1, strikeouts: 9, home_runs: 0,
          pitches: 98, strikes: 67, era: '2.012', whip: '0.987', decision: 'W (11-2)',
        },
      ],
    },
  },
}

afterEach(() => vi.unstubAllGlobals())

describe('GameSummaryView', () => {
  it('renders the final score, inning line, and team batting and pitching box scores', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '80' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith('/api/games/80', expect.objectContaining({ headers: { Accept: 'application/json' } }))
    expect(wrapper.get('[data-test="game-scoreboard"]').text()).toContain('Cleveland Guardians')
    expect(wrapper.get('[data-test="game-scoreboard"]').text()).toContain('Detroit Tigers')
    expect(wrapper.get('[data-test="line-score"]').text()).toContain('End 9th')
    expect(wrapper.get('[data-test="line-score"]').text()).toContain('CLE')
    expect(wrapper.get('[data-test="line-score"]').text()).toContain('DET')
    const insights = wrapper.get('[data-test="game-insights"]').text()
    expect(insights).toContain('Tarik Skubal (W, 11-2)')
    expect(insights).toContain('Tanner Bibee (L, 7-5)')
    expect(insights).toContain('Will Vest (S, 1)')
    expect(insights).toContain('Hits · Errors')
    expect(insights).toContain('Walks · Strikeouts')
    expect(insights).toContain('1-5')
    expect(insights).toContain('2-6')
    const performers = wrapper.get('[data-test="key-performers"]').text()
    expect(performers).toContain('Key performers')
    expect(performers).toContain('Steven Kwan')
    expect(performers).toContain('Riley Greene')
    expect(performers).toContain('Tarik Skubal')
    expect(performers).toContain('Will Vest')
    expect(performers).toContain('1 HR')
    expect(performers).toContain('1.0 scoreless IP · 2 K')
    expect(performers).toContain('3 runs produced')
    const performerLinks = wrapper.findAllComponents(RouterLink).filter((link) => link.props('to')?.name === 'player-profile')
    expect(performerLinks.map((link) => link.props('to').params.id)).toEqual(expect.arrayContaining([20, 21, 23, 24]))
    const scoringTimeline = wrapper.get('[data-test="scoring-play-timeline"]')
    expect(scoringTimeline.text()).toContain('Top 1st')
    expect(scoringTimeline.text()).toContain('Steven Kwan — singles, scoring a run.')
    expect(scoringTimeline.text()).toContain('CLE 1')
    expect(scoringTimeline.text()).toContain('DET 0')
    expect(scoringTimeline.text()).toContain('Bottom 4th')
    expect(scoringTimeline.text()).toContain('Riley Greene — homered, scoring two runs.')
    expect(scoringTimeline.text()).toContain('CLE 1')
    expect(scoringTimeline.text()).toContain('DET 3')
    const scoringLinks = scoringTimeline.findAllComponents(RouterLink)
    expect(scoringLinks.map((link) => link.props('to').params.id)).toEqual([20, 24, 21])
    const boxScore = wrapper.get('[data-test="box-score"]').text()
    expect(boxScore).toContain('Steven Kwan')
    expect(boxScore).toContain('Riley Greene')
    expect(boxScore).toContain('Tanner Bibee')
    expect(boxScore).toContain('Tarik Skubal')
    expect(boxScore).toContain('.842')
    expect(boxScore).not.toContain('0.842')
    expect(boxScore).toContain('2.01')
    expect(boxScore).toContain('0.99')
  })

  it('shows a useful error when the game does not exist', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 404 }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '999' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="game-summary-error"]').text()).toContain('That game could not be found')
  })

  it('renders missing rate statistics as unavailable instead of zero', async () => {
    const missingRatesPayload = structuredClone(payload)
    missingRatesPayload.data.details.batting_lines.forEach((line) => {
      line.batting_average = null
      line.ops = null
    })
    missingRatesPayload.data.details.pitching_lines.forEach((line) => {
      line.era = null
      line.whip = null
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => missingRatesPayload }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '80' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    const boxScore = wrapper.get('[data-test="box-score"]').text()
    expect(boxScore).not.toContain('0.000')
    expect(boxScore).toContain('—')
  })
})

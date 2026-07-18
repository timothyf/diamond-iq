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

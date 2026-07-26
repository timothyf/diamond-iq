import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { vi } from 'vitest'

import PlayerComparisonView from '../PlayerComparisonView.vue'

function profile(id, name, team, stats, careerStats = stats) {
  const [firstName, lastName] = name.split(' ')
  return {
    data: {
      id,
      mlb_id: 600000 + id,
      first_name: firstName,
      last_name: lastName,
      full_name: name,
      team: { id: team.id, name: team.name, abbreviation: team.abbreviation },
      display_team: { id: team.id, name: team.name, abbreviation: team.abbreviation },
      profile: { age: id === 1 ? 25 : 27 },
      positions: { primary: { abbreviation: id === 1 ? 'CF' : 'RF', name: 'Outfielder' }, secondary: [], assignments: [] },
      season_overview: { season: 2026, category: 'batting', preferred_category: 'batting', stats },
      career_overview: {
        category: 'batting', preferred_category: 'batting', first_season: 2022,
        last_season: 2026, season_count: id === 1 ? 5 : 7, columns: [],
        seasons: [], stats: careerStats,
      },
      current_membership: null,
      team_history: [],
      recent_pitch_indicators: { primary_role: 'batter', batting: {}, pitching: {} },
      contextual_benchmarks: {},
      analysis: {},
      source_metadata: {},
    },
  }
}

describe('PlayerComparisonView', () => {
  it('loads URL-selected players and aligns season and career statistics', async () => {
    const responses = {
      '/api/players/1': profile(
        1, 'Riley Greene', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' },
        [{ key: 'homeRuns', label: 'HR', value: '24.0' }, { key: 'ops', label: 'OPS', value: '0.842' }, { key: 'caughtStealing', label: 'CS', value: '5.0' }],
        [{ key: 'homeRuns', label: 'HR', value: '82.0' }, { key: 'ops', label: 'OPS', value: '0.821' }, { key: 'caughtStealing', label: 'CS', value: '11.0' }],
      ),
      '/api/players/2': profile(
        2, 'Aaron Judge', { id: 11, name: 'New York Yankees', abbreviation: 'NYY' },
        [{ key: 'homeRuns', label: 'HR', value: '38' }, { key: 'avg', label: 'AVG', value: '0.311' }, { key: 'caughtStealing', label: 'CS', value: '2' }],
        [{ key: 'homeRuns', label: 'HR', value: '353' }, { key: 'avg', label: 'AVG', value: '0.288' }, { key: 'caughtStealing', label: 'CS', value: '7' }],
      ),
    }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({
      ok: true,
      json: async () => responses[url],
    })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith('/api/players/1', expect.any(Object))
    expect(fetch).toHaveBeenCalledWith('/api/players/2', expect.any(Object))
    expect(wrapper.get('[data-test="comparison-identities"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="comparison-identities"]').text()).toContain('Aaron Judge')
    const season = wrapper.get('[data-test="season-comparison"]')
    expect(season.text()).toContain('24')
    expect(season.text()).not.toContain('24.0')
    expect(season.text()).toContain('38')
    expect(season.text()).toContain('0.842')
    expect(season.text()).toContain('0.311')
    expect(season.text()).toContain('—')
    const homeRuns = wrapper.get('[data-test="season-stat-homeRuns"]')
    expect(homeRuns.findAll('td')[0].classes()).toContain('is-lesser')
    expect(homeRuns.findAll('td')[1].classes()).toContain('is-better')
    const caughtStealing = wrapper.get('[data-test="season-stat-caughtStealing"]')
    expect(caughtStealing.findAll('td')[0].classes()).toContain('is-lesser')
    expect(caughtStealing.findAll('td')[1].classes()).toContain('is-better')
    const career = wrapper.get('[data-test="career-comparison"]')
    expect(career.text()).toContain('82')
    expect(career.text()).toContain('353')
  })
})

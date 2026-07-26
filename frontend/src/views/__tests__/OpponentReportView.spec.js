import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import OpponentReportView from '../OpponentReportView.vue'

const RouterLinkStub = {
  name: 'RouterLink',
  props: ['to'],
  template: '<a><slot /></a>',
}

describe('OpponentReportView', () => {
  it('renders the frozen series, scouting details, and evidence links', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: {
          id: 301,
          title: 'DET vs CLE · Jul 16–Jul 17, 2026',
          generated_at: '2026-07-15T14:00:00Z',
          series_starts_on: '2026-07-16',
          series_ends_on: '2026-07-17',
          team: { id: 1, name: 'Detroit Tigers' },
          opponent: { id: 2, name: 'Cleveland Guardians' },
          snapshot: {
            opponent: { id: 2, name: 'Cleveland Guardians' },
            recent_performance: { wins: 7, losses: 3, runs_per_game: 4.8, ops: 0.781, era: 3.42 },
            series: [{
              id: 81,
              official_date: '2026-07-16',
              venue_name: 'Comerica Park',
              home_team: { abbreviation: 'DET' },
              away_team: { abbreviation: 'CLE' },
              home_probable_pitcher: { full_name: 'Tarik Skubal' },
              away_probable_pitcher: { full_name: 'Tanner Bibee' },
            }],
            probable_starters: [{
              player: { id: 52, full_name: 'Tanner Bibee' },
              throws: 'R',
              sample_size: 200,
              repertoire: [{
                pitch_type: 'FF',
                pitch_name: '4-Seam Fastball',
                usage_percentage: 50,
                average_velocity: 95.6,
                horizontal_break: -7.2,
                vertical_break: 14.4,
                evidence: [{ game_id: 80, pitch_id: 1001 }],
              }],
              handedness_splits: [{
                batter_hand: 'L', plate_appearances: 24, strikeout_rate: 29.2, whiff_rate: 31.5,
                evidence: [{ game_id: 80, plate_appearance_id: 901 }],
              }],
              recent_changes: [{
                key: 'velocity', label: 'Average velocity', change: 1.2, unit: 'mph',
                evidence: [{ game_id: 80, pitch_id: 1001 }],
              }],
            }],
          },
        },
      }),
    }))

    const wrapper = mount(OpponentReportView, {
      props: { reportId: '301' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('DET vs CLE')
    expect(wrapper.text()).toContain('Data is preserved as of this time')
    expect(wrapper.text()).toContain('Tanner Bibee')
    expect(wrapper.text()).toContain('4-Seam Fastball')
    expect(wrapper.text()).toContain('vs LHB')
    expect(wrapper.text()).toContain('+1.2 mph')
    expect(wrapper.getComponent('tbody a').props('to')).toEqual({
      name: 'game-summary',
      params: { id: 80 },
      hash: '#pitch-1001',
    })
  })
})

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
    const print = vi.spyOn(window, 'print').mockImplementation(() => {})
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
              usage_by_count: [{
                count: '0-0', pitches: 80, percentage: 40,
                repertoire: [{ pitch_type: 'FF', pitch_name: '4-Seam Fastball', percentage: 50 }],
                evidence: [{ game_id: 80, pitch_id: 1001 }],
              }],
              first_pitch_tendencies: {
                pitches: 40,
                repertoire: [{ pitch_type: 'FF', pitch_name: '4-Seam Fastball', percentage: 52 }],
                location_zones: [{ label: 'Zone 1', percentage: 25 }],
              },
              two_strike_tendencies: {
                pitches: 60,
                repertoire: [{ pitch_type: 'SL', pitch_name: 'Slider', percentage: 58 }],
                location_zones: [{ label: 'Zone 8', percentage: 30 }],
              },
              location_zones: [{ zone: 1, label: 'Zone 1', percentage: 25 }],
              put_away_pitches: [{
                pitch_type: 'SL', pitch_name: 'Slider', strikeouts: 8, strikeout_rate: 42,
              }],
              times_through_order: [{ order: 1, plate_appearances: 20, strikeout_rate: 30 }],
              hitter_attack_plan: [{
                key: 'first_pitch', label: 'First-pitch plan',
                recommendation: 'Expect 4-Seam Fastball early and be ready to attack it in the zone.',
                rationale: 'It is the most frequent first pitch (52%).',
                evidence: [{ game_id: 80, pitch_id: 1001 }],
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
    expect(wrapper.text()).toContain('Usage by count')
    expect(wrapper.text()).toContain('Two-strike tendencies')
    expect(wrapper.text()).toContain('Slider')
    expect(wrapper.get('[data-test="hitter-attack-plan"]').text()).toContain('Evidence-backed hitter attack plan')
    expect(wrapper.get('[data-test="print-report"]').text()).toContain('Print / PDF')
    await wrapper.get('[data-test="print-report"]').trigger('click')
    expect(print).toHaveBeenCalledTimes(1)
    expect(wrapper.getComponent('tbody a').props('to')).toEqual({
      name: 'game-summary',
      params: { id: 80 },
      hash: '#pitch-1001',
    })
  })
})

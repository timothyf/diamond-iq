import { computed, nextTick, ref } from 'vue'
import { mount } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'

import PlayerSeasonStatsDashboard from '../PlayerSeasonStatsDashboard.vue'

const refreshSpy = vi.fn()
const importFileSpy = vi.fn()

vi.mock('../../composables/usePlayerSeasonStats', () => ({
  usePlayerSeasonStats: vi.fn(() => ({
    rows: ref([
      {
        id: 1,
        rank: 1,
        season: 2024,
        player: { full_name: 'Miguel Cabrera', mlb_id: 408234 },
        team: { abbreviation: 'DET', name: 'Detroit Tigers' },
        stats: { gamesPlayed: '150', homeRuns: '24', ops: '0.887' },
      },
    ]),
    meta: ref({
      page: 1,
      totalPages: 2,
      totalCount: 14,
      sort: '-homeRuns',
      filters: {},
      category: 'batting',
      availableSeasons: [2026, 2025, 2024],
      availableTeams: [
        { id: 1, abbreviation: 'DET', short_name: 'Tigers', name: 'Detroit Tigers' },
        { id: 2, abbreviation: 'LAD', short_name: 'Dodgers', name: 'Los Angeles Dodgers' },
      ],
      columns: [
        { key: 'gamesPlayed', label: 'G', align: 'numeric' },
        { key: 'homeRuns', label: 'HR', align: 'numeric' },
        { key: 'ops', label: 'OPS', align: 'numeric' },
      ],
    }),
    loading: computed(() => false),
    error: computed(() => ''),
    refresh: refreshSpy,
  })),
}))

vi.mock('../../composables/usePlayerSeasonStatsImport', () => ({
  usePlayerSeasonStatsImport: vi.fn(() => ({
    uploading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    importFile: importFileSpy,
  })),
}))

describe('PlayerSeasonStatsDashboard', () => {
  beforeEach(() => {
    refreshSpy.mockClear()
    importFileSpy.mockReset()
    importFileSpy.mockResolvedValue({
      message: 'Imported 1 player season stats',
      data: { imported_count: 1 },
    })
  })

  it('renders the table controls and summary metrics', () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    expect(wrapper.text()).toContain('Player Season Stat Board')
    expect(wrapper.text()).toContain('Stage A Player Season Stats Import')
    expect(wrapper.text()).toContain('Players In View')
    expect(wrapper.text()).toContain('Matching Players')
    expect(wrapper.text()).toContain('14')
    expect(wrapper.text()).toContain('Category: batting')
  })

  it('updates and resets the filter summary', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const playerInput = wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]')
    const teamSelect = wrapper.find('select[data-test="team-filter"]')
    const seasonSelect = wrapper.find('select[data-test="season-filter"]')

    await playerInput.setValue('Ohtani')
    await teamSelect.setValue('2')
    await seasonSelect.setValue('2026')

    expect(wrapper.text()).toContain('Player: Ohtani · Team: LAD · Season: 2026')

    const resetButton = wrapper.findAll('button.ghost-button').find((button) => button.text().includes('Reset Filters'))
    await resetButton.trigger('click')
    await nextTick()

    expect(playerInput.element.value).toBe('')
    expect(teamSelect.element.value).toBe('')
    expect(seasonSelect.element.value).toBe('')
    expect(wrapper.text()).toContain('Category: batting')
  })

  it('renders season options from available data years', () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const seasonSelect = wrapper.find('select[data-test="season-filter"]')

    expect(seasonSelect.text()).toContain('All seasons')
    expect(seasonSelect.text()).toContain('2026')
    expect(seasonSelect.text()).toContain('2025')
    expect(seasonSelect.text()).toContain('2024')
  })

  it('renders team options from available teams', () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const teamSelect = wrapper.find('select[data-test="team-filter"]')

    expect(teamSelect.text()).toContain('All teams')
    expect(teamSelect.text()).toContain('DET · Tigers')
    expect(teamSelect.text()).toContain('LAD · Dodgers')
  })

  it('calls refresh when the refresh button is clicked', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const refreshButton = wrapper.findAll('button.ghost-button').find((button) => button.text().includes('Refresh Data'))
    await refreshButton.trigger('click')

    expect(refreshSpy).toHaveBeenCalledTimes(1)
  })

  it('updates the import status when a csv file is selected', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const file = new File(['season,player'], 'season-stats.csv', { type: 'text/csv' })
    const input = wrapper.find('input[type="file"]')

    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [file],
    })

    await input.trigger('change')
    await nextTick()

    expect(wrapper.text()).toContain('season-stats.csv is selected and ready to import.')
  })

  it('uploads the selected csv and refreshes the board', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const file = new File(['season,player'], 'season-stats.csv', { type: 'text/csv' })
    const input = wrapper.find('input[type="file"]')

    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [file],
    })

    await input.trigger('change')
    await nextTick()

    const importButton = wrapper.findAll('button.ghost-button').find((button) => button.text().includes('Import CSV'))
    await importButton.trigger('click')
    await nextTick()

    expect(importFileSpy).toHaveBeenCalledWith(file)
    expect(refreshSpy).toHaveBeenCalledTimes(1)
  })
})

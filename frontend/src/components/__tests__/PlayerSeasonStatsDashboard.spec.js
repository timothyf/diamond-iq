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

vi.mock('../../composables/usePlayerSuggestions', () => ({
  usePlayerSuggestions: vi.fn(() => ({
    suggestions: computed(() => [
      {
        id: 42,
        fullName: 'Miguel Cabrera',
        team: { abbreviation: 'DET' },
      },
      {
        id: 43,
        fullName: 'Mike Trout',
        team: { abbreviation: 'LAA' },
      },
    ]),
    loading: computed(() => false),
    error: computed(() => ''),
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
    expect(wrapper.text()).toContain('Data import')
    expect(wrapper.text()).toContain('Batting Leaderboard')
    expect(wrapper.text()).toContain('Category: batting')
  })

  it('updates the leaderboard title when the category changes', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Stats'))

    expect(wrapper.text()).toContain('Batting Leaderboard')

    await categorySelect.setValue('pitching')

    expect(wrapper.text()).toContain('Pitching Leaderboard')
    expect(wrapper.text()).not.toContain('Batting Leaderboard')
  })

  it('opens the import drawer from the table header action', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const importButton = wrapper.find('[data-test="open-import-panel"]')
    await importButton.trigger('click')

    expect(wrapper.text()).toContain('Refresh Player Season Stats')
    expect(wrapper.text()).toContain('Player Season Stats Import')
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

  it('shows player suggestions and applies a selected suggestion', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const playerInput = wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]')

    await playerInput.setValue('Mig')
    await playerInput.trigger('focus')

    expect(wrapper.text()).toContain('Miguel Cabrera')
    expect(wrapper.text()).toContain('Mike Trout')

    const suggestionButton = wrapper.findAll('.typeahead-option').find((button) => button.text().includes('Miguel Cabrera'))
    await suggestionButton.trigger('mousedown')
    await nextTick()

    expect(playerInput.element.value).toBe('Miguel Cabrera')
    expect(wrapper.findAll('.typeahead-option')).toHaveLength(0)
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
    const openImportButton = wrapper.find('[data-test="open-import-panel"]')
    await openImportButton.trigger('click')

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
    const openImportButton = wrapper.find('[data-test="open-import-panel"]')
    await openImportButton.trigger('click')

    const file = new File(['season,player'], 'season-stats.csv', { type: 'text/csv' })
    const input = wrapper.find('input[type="file"]')

    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [file],
    })

    await input.trigger('change')
    await nextTick()

    const importButton = wrapper.find('[data-test="execute-import"]')
    await importButton.trigger('click')
    await nextTick()

    expect(importFileSpy).toHaveBeenCalledWith(file)
    expect(refreshSpy).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).not.toContain('Refresh Player Season Stats')
  })
})

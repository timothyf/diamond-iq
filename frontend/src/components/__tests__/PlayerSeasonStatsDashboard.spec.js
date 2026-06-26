import { computed, nextTick, ref } from 'vue'
import { mount } from '@vue/test-utils'
import { flushPromises } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'

import PlayerSeasonStatsDashboard from '../PlayerSeasonStatsDashboard.vue'

const refreshSpy = vi.fn()
const refreshPitchDataSpy = vi.fn()
const importFileSpy = vi.fn()
const importPitchDataFileSpy = vi.fn()
const downloadStatsSpy = vi.fn()
const downloadPitchDataSpy = vi.fn()

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
      dataRange: { type: 'season', start: 1970, end: 2026 },
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

vi.mock('../../composables/usePitchData', () => ({
  usePitchData: vi.fn(() => ({
    rows: computed(() => [
      {
        id: 12,
        rank: 1,
        gameDate: '2026-04-30',
        gamePk: 777,
        atBatNumber: 3,
        pitchNumber: 2,
        pitcher: 9001,
        pitcherName: 'Matthew Boyd',
        playerName: 'Pitcher One',
        batter: 8001,
        batterName: 'Shohei Ohtani',
        pitchType: 'FF',
        releaseSpeed: 97.8,
        releaseSpinRate: 2350,
        launchSpeed: 105.4,
        launchAngle: 17.2,
        hitDistanceSc: 398,
        zone: 1,
        inning: 5,
        description: 'called_strike',
        events: 'strikeout',
        pitchName: '4-Seam Fastball',
      },
    ]),
    meta: computed(() => ({
      count: 1,
      limit: 50,
      perPage: 50,
      page: 1,
      totalPages: 1,
      totalCount: 1,
      dataRange: { type: 'game_date', start: '2026-04-01', end: '2026-04-30' },
      availableEvents: ['double', 'strikeout', 'walk'],
      availablePitchTypes: ['FF', 'SL'],
    })),
    loading: computed(() => false),
    error: computed(() => ''),
    refresh: refreshPitchDataSpy,
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

vi.mock('../../composables/usePitchDataDownload', () => ({
  usePitchDataDownload: vi.fn(() => ({
    downloading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    downloadPitchData: downloadPitchDataSpy,
  })),
}))

vi.mock('../../composables/usePlayerSeasonStatsDownload', () => ({
  usePlayerSeasonStatsDownload: vi.fn(() => ({
    downloading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    downloadStats: downloadStatsSpy,
  })),
}))

vi.mock('../../composables/usePitchDataImport', () => ({
  usePitchDataImport: vi.fn(() => ({
    uploading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    importFile: importPitchDataFileSpy,
  })),
}))

describe('PlayerSeasonStatsDashboard', () => {
  beforeEach(() => {
    window.history.replaceState({}, '', '/')
    refreshSpy.mockClear()
    refreshPitchDataSpy.mockClear()
    importFileSpy.mockReset()
    importPitchDataFileSpy.mockReset()
    downloadStatsSpy.mockReset()
    downloadPitchDataSpy.mockReset()
    importFileSpy.mockResolvedValue({
      message: 'Imported 1 player season stats',
      data: { imported_count: 1 },
    })
    importPitchDataFileSpy.mockResolvedValue({
      message: 'Imported 1 pitch data rows',
      data: { imported_count: 1 },
    })
    downloadStatsSpy.mockResolvedValue({
      message: 'Imported 2 player season stats',
      data: { imported_count: 2, downloaded_count: 1 },
    })
    downloadPitchDataSpy.mockResolvedValue({
      message: 'Imported 1 pitch data rows',
      data: { imported_count: 1, downloaded_count: 1 },
    })
  })

  it('renders the table controls and summary metrics', () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    expect(wrapper.text()).toContain('Player Season Stat Board')
    expect(wrapper.text()).toContain('Data import')
    expect(wrapper.text()).toContain('Batting Leaderboard')
    expect(wrapper.text()).toContain('Category: batting')
    expect(wrapper.text()).toContain('Data range: 1970-2026 seasons')
  })

  it('hydrates leaderboard filters from the URL query string', () => {
    window.history.replaceState(
      {},
      '',
      '/?category=pitching&player=Al+Kaline&team=2&season_start=2025&season_end=2026&per_page=30&sort=season',
    )

    const wrapper = mount(PlayerSeasonStatsDashboard)
    const playerInput = wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]')
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    expect(categorySelect.element.value).toBe('pitching')
    expect(playerInput.element.value).toBe('Al Kaline')
    expect(wrapper.find('[data-test="team-filter"]').element.value).toBe('2')
    expect(wrapper.find('[data-test="season-start-filter"]').element.value).toBe('2025')
    expect(wrapper.find('[data-test="season-end-filter"]').element.value).toBe('2026')
    expect(wrapper.text()).toContain('Player: Al Kaline · Team: LAD · Seasons: 2025-2026 · Category: pitching')
  })

  it('writes selected leaderboard filters to the URL query string', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    await wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]').setValue('Al Kaline')
    await wrapper.find('[data-test="team-filter"]').setValue('2')
    await wrapper.find('[data-test="season-start-filter"]').setValue('2025')
    await wrapper.find('[data-test="season-end-filter"]').setValue('2026')
    await wrapper.findAll('select').find((select) => select.text().includes('100')).setValue('30')
    await nextTick()

    const searchParams = new URLSearchParams(window.location.search)
    expect(searchParams.get('player')).toBe('Al Kaline')
    expect(searchParams.get('team')).toBe('2')
    expect(searchParams.get('season_start')).toBe('2025')
    expect(searchParams.get('season_end')).toBe('2026')
    expect(searchParams.get('per_page')).toBe('30')
  })

  it('writes selected pitch data filters to the URL query string', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    await categorySelect.setValue('pitchData')
    await wrapper.find('[data-test="pitch-game-date-start-filter"]').setValue('2026-04-29')
    await wrapper.find('[data-test="pitch-game-date-end-filter"]').setValue('2026-04-30')
    await wrapper.find('[data-test="pitch-game-pk-filter"]').setValue('777')
    await wrapper.find('[data-test="pitch-type-filter"]').setValue('FF')
    await wrapper.find('[data-test="pitch-events-filter"]').setValue('strikeout')
    await nextTick()

    const searchParams = new URLSearchParams(window.location.search)
    expect(searchParams.get('category')).toBe('pitchData')
    expect(searchParams.get('game_date_start')).toBe('2026-04-29')
    expect(searchParams.get('game_date_end')).toBe('2026-04-30')
    expect(searchParams.get('game_pk')).toBe('777')
    expect(searchParams.get('pitch_type')).toBe('FF')
    expect(searchParams.get('events')).toBe('strikeout')
  })

  it('updates the leaderboard title when the category changes', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    expect(wrapper.text()).toContain('Batting Leaderboard')

    await categorySelect.setValue('pitching')

    expect(wrapper.text()).toContain('Pitching Leaderboard')
    expect(wrapper.text()).not.toContain('Batting Leaderboard')

    await categorySelect.setValue('pitchData')

    expect(wrapper.text()).toContain('Pitch Data Feed')
  })

  it('shows pitch-only filters in pitch data mode and hides them in leaderboard modes', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    expect(wrapper.find('[data-test="pitch-game-date-start-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-game-date-end-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-game-pk-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-pitcher-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-batter-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-type-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-events-filter"]').exists()).toBe(false)

    await categorySelect.setValue('pitchData')

    expect(wrapper.find('[data-test="pitch-game-date-start-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="pitch-game-date-end-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="pitch-game-pk-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="pitch-pitcher-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="pitch-batter-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="pitch-type-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="pitch-events-filter"]').exists()).toBe(true)

    expect(wrapper.find('[data-test="pitch-type-filter"]').text()).toContain('Any')
    expect(wrapper.find('[data-test="pitch-type-filter"]').text()).toContain('FF')
    expect(wrapper.find('[data-test="pitch-events-filter"]').text()).toContain('Any')
    expect(wrapper.find('[data-test="pitch-events-filter"]').text()).toContain('double')
    expect(wrapper.find('[data-test="pitch-events-filter"]').text()).toContain('strikeout')
    expect(wrapper.find('[data-test="pitch-events-filter"]').text()).toContain('walk')

    await wrapper.find('[data-test="pitch-game-date-start-filter"]').setValue('2026-04-29')
    await wrapper.find('[data-test="pitch-game-date-end-filter"]').setValue('2026-04-30')
    await wrapper.find('[data-test="pitch-game-pk-filter"]').setValue('777')
    await wrapper.find('[data-test="pitch-pitcher-filter"]').setValue('9001')
    await wrapper.find('[data-test="pitch-batter-filter"]').setValue('8001')
    await wrapper.find('[data-test="pitch-type-filter"]').setValue('FF')
    await wrapper.find('[data-test="pitch-events-filter"]').setValue('strikeout')

    expect(wrapper.text()).toContain('Game Dates: 2026-04-29 to 2026-04-30')
    expect(wrapper.text()).toContain('Game PK: 777')
    expect(wrapper.text()).toContain('Pitcher: 9001')
    expect(wrapper.text()).toContain('Batter: 8001')
    expect(wrapper.text()).toContain('Pitch Type: FF')
    expect(wrapper.text()).toContain('Events: strikeout')

    // leaderboard-only filters are hidden in pitch data mode
    expect(wrapper.find('[data-test="season-start-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="season-end-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="team-filter"]').exists()).toBe(false)
    expect(wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]').exists()).toBe(false)

    await categorySelect.setValue('batting')

    expect(wrapper.find('[data-test="pitch-game-date-start-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-game-date-end-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-game-pk-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-pitcher-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-batter-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-type-filter"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="pitch-events-filter"]').exists()).toBe(false)
    // leaderboard-only filters are visible again
    expect(wrapper.find('[data-test="season-start-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="season-end-filter"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="team-filter"]').exists()).toBe(true)
    expect(wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]').exists()).toBe(true)
  })

  it('clears the pitcher field on focus after a pitcher is chosen', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    await categorySelect.setValue('pitchData')

    const pitcherInput = wrapper.find('[data-test="pitch-pitcher-filter"]')

    await pitcherInput.setValue('Mig')
    await pitcherInput.trigger('focus')
    await new Promise((resolve) => setTimeout(resolve, 250))
    await flushPromises()

    const pitcherSuggestionButton = wrapper.findAll('.typeahead-option').find((button) => button.text().includes('Miguel Cabrera'))
    expect(pitcherSuggestionButton).toBeTruthy()
    await pitcherSuggestionButton.trigger('mousedown')
    await nextTick()

    expect(pitcherInput.element.value).toBe('Miguel Cabrera')

    await pitcherInput.trigger('focus')

    expect(pitcherInput.element.value).toBe('')
  })

  it('opens the import drawer from the table header action', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const importButton = wrapper.find('[data-test="open-import-panel"]')
    await importButton.trigger('click')

    expect(wrapper.text()).toContain('Import CSV Data')
    expect(wrapper.text()).toContain('CSV Import')
  })

  it('updates and resets the filter summary', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const playerInput = wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]')
    const teamSelect = wrapper.find('select[data-test="team-filter"]')
    const seasonStartSelect = wrapper.find('select[data-test="season-start-filter"]')
    const seasonEndSelect = wrapper.find('select[data-test="season-end-filter"]')

    await playerInput.setValue('Ohtani')
    await teamSelect.setValue('2')
    await seasonStartSelect.setValue('2025')
    await seasonEndSelect.setValue('2026')

    expect(wrapper.text()).toContain('Player: Ohtani · Team: LAD · Seasons: 2025-2026')

    const resetButton = wrapper.findAll('button.ghost-button').find((button) => button.text().includes('Reset Filters'))
    await resetButton.trigger('click')
    await nextTick()

    expect(playerInput.element.value).toBe('')
    expect(teamSelect.element.value).toBe('')
    expect(seasonStartSelect.element.value).toBe('')
    expect(seasonEndSelect.element.value).toBe('')
    expect(wrapper.text()).toContain('Category: batting')
  })

  it('preserves pitch data category when resetting pitch filters', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    await categorySelect.setValue('pitchData')
    await wrapper.find('[data-test="pitch-game-date-start-filter"]').setValue('2026-04-29')
    await wrapper.find('[data-test="pitch-pitcher-filter"]').setValue('Matthew')

    const resetButton = wrapper.findAll('button.ghost-button').find((button) => button.text().includes('Reset Filters'))
    await resetButton.trigger('click')
    await nextTick()

    expect(wrapper.find('[data-test="pitch-game-date-start-filter"]').element.value).toBe('')
    expect(wrapper.find('[data-test="pitch-pitcher-filter"]').element.value).toBe('')
    expect(categorySelect.element.value).toBe('pitchData')
    expect(wrapper.text()).toContain('Showing latest imported pitch rows (50 per page).')
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
    const seasonStartSelect = wrapper.find('select[data-test="season-start-filter"]')
    const seasonEndSelect = wrapper.find('select[data-test="season-end-filter"]')

    expect(seasonStartSelect.text()).toContain('Any')
    expect(seasonStartSelect.text()).toContain('2026')
    expect(seasonStartSelect.text()).toContain('2025')
    expect(seasonStartSelect.text()).toContain('2024')
    expect(seasonEndSelect.text()).toContain('Any')
    expect(seasonEndSelect.text()).toContain('2026')
    expect(seasonEndSelect.text()).toContain('2025')
    expect(seasonEndSelect.text()).toContain('2024')
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

  it('downloads MLB stats and refreshes the leaderboard', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    await wrapper.find('[data-test="mlb-download-category"]').setValue('pitching')
    await wrapper.find('[data-test="mlb-download-start-year"]').setValue('2025')
    await wrapper.find('[data-test="mlb-download-end-year"]').setValue('2026')
    await wrapper.find('[data-test="mlb-download-panel"]').trigger('submit')
    await flushPromises()
    await nextTick()

    expect(downloadStatsSpy).toHaveBeenCalledWith({
      category: 'pitching',
      startYear: 2025,
      endYear: 2026,
      replaceSeason: true,
    })
    expect(refreshSpy).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).toContain('Pitching Leaderboard')
  })

  it('downloads pitch data and refreshes the pitch feed', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    await wrapper.find('[data-test="mlb-download-category"]').setValue('pitchData')
    await nextTick()

    expect(wrapper.text()).toContain('Download Pitch Data')
    expect(wrapper.find('[data-test="mlb-download-start-date"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="mlb-download-start-year"]').exists()).toBe(false)

    await wrapper.find('[data-test="mlb-download-start-date"]').setValue('2026-04-01')
    await wrapper.find('[data-test="mlb-download-end-date"]').setValue('2026-04-02')
    await wrapper.find('[data-test="mlb-download-game-types"]').setValue('R,F')
    await wrapper.find('[data-test="mlb-download-chunk-days"]').setValue(3)
    await wrapper.find('[data-test="mlb-download-panel"]').trigger('submit')
    await flushPromises()
    await nextTick()

    expect(downloadPitchDataSpy).toHaveBeenCalledWith({
      startDate: '2026-04-01',
      endDate: '2026-04-02',
      gameTypes: 'R,F',
      chunkDays: 3,
    })
    expect(refreshPitchDataSpy).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).toContain('Pitch Data Feed')
    expect(wrapper.text()).toContain('Game Dates: 2026-04-01 to 2026-04-02')
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
    await flushPromises()
    await nextTick()

    expect(importFileSpy).toHaveBeenCalledWith(file, { replaceSeason: false })
    expect(refreshSpy).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).not.toContain('Import CSV Data')
  })

  it('uploads a pitch csv from the unified import drawer', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const openImportButton = wrapper.find('[data-test="open-import-panel"]')
    await openImportButton.trigger('click')
    await nextTick()

    expect(wrapper.text()).toContain('Import CSV Data')

    const file = new File(['game_pk,at_bat_number,pitch_number'], 'pitch-data.csv', { type: 'text/csv' })
    const input = wrapper.find('input[type="file"]')

    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [file],
    })

    await input.trigger('change')
    await nextTick()

    const importButton = wrapper.find('[data-test="execute-import"]')
    await importButton.trigger('click')
    await flushPromises()
    await nextTick()

    expect(importPitchDataFileSpy).toHaveBeenCalledWith(file)
    expect(refreshPitchDataSpy).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).not.toContain('Import CSV Data')
  })

  it('renders the pitch data table when pitch data category is selected', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)
    const categorySelect = wrapper.findAll('select').find((select) => select.text().includes('Pitch Data'))

    await categorySelect.setValue('pitchData')

    expect(wrapper.text()).toContain('Showing latest imported pitch rows (50 per page).')
    expect(wrapper.text()).toContain('Data range: 2026-04-01 to 2026-04-30')
    expect(wrapper.text()).toContain('Showing 1 of 1 pitch rows')
    expect(wrapper.text()).toContain('FF')
    expect(wrapper.text()).toContain('97.8')
    expect(wrapper.text()).toContain('2350')
    expect(wrapper.text()).toContain('105.4')
    expect(wrapper.text()).toContain('17.2')
    expect(wrapper.text()).toContain('398')
    expect(wrapper.text()).toContain('called_strike')
    expect(wrapper.text()).toContain('strikeout')
  })
})

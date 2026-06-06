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
        value: '3.2',
        season: 2024,
        player: { full_name: 'Miguel Cabrera', mlb_id: 408234 },
        team: { abbreviation: 'DET', name: 'Detroit Tigers' },
        stat_type: { label: 'WAR', name: 'war', category: 'batting' },
      },
    ]),
    meta: ref({
      page: 1,
      totalPages: 2,
      totalCount: 14,
      sort: '-value',
      filters: {},
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
    expect(wrapper.text()).toContain('Rows In View')
    expect(wrapper.text()).toContain('Total Matches')
    expect(wrapper.text()).toContain('14')
    expect(wrapper.text()).toContain('Showing the full player season stat board.')
  })

  it('updates and resets the filter summary', async () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    const playerInput = wrapper.find('input[placeholder="Ohtani, Cabrera, Trout..."]')
    const teamInput = wrapper.find('input[placeholder="Dodgers, Tigers..."]')

    await playerInput.setValue('Ohtani')
    await teamInput.setValue('Dodgers')

    expect(wrapper.text()).toContain('Player: Ohtani · Team: Dodgers')

    const resetButton = wrapper.findAll('button.ghost-button').find((button) => button.text().includes('Reset Filters'))
    await resetButton.trigger('click')
    await nextTick()

    expect(playerInput.element.value).toBe('')
    expect(teamInput.element.value).toBe('')
    expect(wrapper.text()).toContain('Showing the full player season stat board.')
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

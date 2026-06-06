import { computed, ref } from 'vue'
import { mount } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'

import PlayerSeasonStatsDashboard from '../PlayerSeasonStatsDashboard.vue'

const refreshSpy = vi.fn()

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

describe('PlayerSeasonStatsDashboard', () => {
  beforeEach(() => {
    refreshSpy.mockClear()
  })

  it('renders the table controls and summary metrics', () => {
    const wrapper = mount(PlayerSeasonStatsDashboard)

    expect(wrapper.text()).toContain('Player Season Stat Board')
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

    await wrapper.find('button.ghost-button').trigger('click')

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
})

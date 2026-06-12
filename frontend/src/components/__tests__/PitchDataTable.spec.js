import { mount } from '@vue/test-utils'

import PitchDataTable from '../PitchDataTable.vue'

function buildProps(overrides = {}) {
  return {
    rows: [
      {
        id: 1,
        rank: 1,
        gameDate: '2026-04-30',
        gamePk: 888,
        atBatNumber: 3,
        pitchNumber: 2,
        pitcher: 9001,
        pitcherName: 'Matthew Boyd',
        batter: 8001,
        batterName: 'Shohei Ohtani',
        pitchType: 'FF',
        count: '2-1',
        zone: 7,
        inning: 6,
        inningDisplay: 'Top 6',
        pitchName: '4-Seam Fastball',
        description: 'called_strike',
        events: 'strikeout',
        playerName: 'Pitcher One',
      },
    ],
    meta: {
      count: 1,
      limit: 50,
    },
    loading: false,
    ...overrides,
  }
}

describe('PitchDataTable', () => {
  it('renders pitch row data and metadata', () => {
    const wrapper = mount(PitchDataTable, {
      props: buildProps(),
    })

    expect(wrapper.text()).toContain('Showing 1 of 1 pitch rows')
    expect(wrapper.text()).toContain('Page 1 of 1')
    expect(wrapper.find('th').text()).toContain('Game')
    expect(wrapper.find('.game-cell .game-pk').text()).toBe('888')
    expect(wrapper.find('.game-cell .game-date').text()).toBe('2026-04-30')
    expect(wrapper.text()).toContain('2026-04-30')
    expect(wrapper.text()).toContain('FF')
    expect(wrapper.text()).toContain('2-1')
    expect(wrapper.text()).toContain('Matthew Boyd')
    expect(wrapper.text()).toContain('Top 6')
    expect(wrapper.find('.zone-icon.selected-7').exists()).toBe(true)
    expect(wrapper.find('.zone-icon .zone-7').exists()).toBe(true)
  })

  it('shows loading empty state when there are no rows', () => {
    const wrapper = mount(PitchDataTable, {
      props: buildProps({
        rows: [],
        loading: true,
        meta: { count: 0, limit: 50 },
      }),
    })

    expect(wrapper.text()).toContain('Loading pitch data…')
  })

  it('emits first, previous, next, and last page changes', async () => {
    const wrapper = mount(PitchDataTable, {
      props: buildProps({
        meta: {
          count: 1,
          limit: 50,
          page: 3,
          totalPages: 7,
        },
      }),
    })

    const buttons = wrapper.findAll('button')

    await buttons[0].trigger('click')
    await buttons[1].trigger('click')
    await buttons[2].trigger('click')
    await buttons[3].trigger('click')

    expect(wrapper.emitted('page-change')).toEqual([[1], [2], [4], [7]])
  })
})

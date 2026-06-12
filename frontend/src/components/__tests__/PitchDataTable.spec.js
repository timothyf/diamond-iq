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
        batter: 8001,
        pitchType: 'FF',
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

    expect(wrapper.text()).toContain('Showing 1 pitch rows')
    expect(wrapper.text()).toContain('Limit 50')
    expect(wrapper.text()).toContain('2026-04-30')
    expect(wrapper.text()).toContain('4-Seam Fastball')
    expect(wrapper.text()).toContain('Pitcher One')
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
})
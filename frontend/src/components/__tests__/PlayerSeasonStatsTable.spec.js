import { mount } from '@vue/test-utils'

import PlayerSeasonStatsTable from '../PlayerSeasonStatsTable.vue'

function buildProps(overrides = {}) {
  return {
    rows: [
      {
        id: 1,
        season: 2024,
        value: '3.2',
        player: {
          full_name: 'Miguel Cabrera',
          mlb_id: 408234,
        },
        team: {
          abbreviation: 'DET',
          name: 'Detroit Tigers',
        },
        stat_type: {
          label: 'WAR',
          name: 'war',
          category: 'batting',
        },
      },
    ],
    meta: {
      page: 2,
      totalPages: 3,
      totalCount: 25,
    },
    loading: false,
    sort: '-value',
    ...overrides,
  }
}

describe('PlayerSeasonStatsTable', () => {
  it('renders the row data and metadata', () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps(),
    })

    expect(wrapper.text()).toContain('Page 2 of 3')
    expect(wrapper.text()).toContain('25 total matching rows')
    expect(wrapper.text()).toContain('Miguel Cabrera')
    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('WAR')
    expect(wrapper.text()).toContain('3.2')
  })

  it('emits sort-change when a column header is clicked', async () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({ sort: 'value' }),
    })

    const valueHeader = wrapper.findAll('th button').find((button) => button.text().includes('Value'))
    await valueHeader.trigger('click')

    expect(wrapper.emitted('sort-change')).toEqual([['-value']])
  })

  it('emits page-change when navigating pagination', async () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps(),
    })

    const [previousButton, nextButton] = wrapper.findAll('footer button')

    await previousButton.trigger('click')
    await nextButton.trigger('click')

    expect(wrapper.emitted('page-change')).toEqual([[1], [3]])
  })

  it('shows the loading empty state when there are no rows', () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({
        rows: [],
        loading: true,
        meta: {
          page: 1,
          totalPages: 0,
          totalCount: 0,
        },
      }),
    })

    expect(wrapper.text()).toContain('Loading player season stats…')
  })
})

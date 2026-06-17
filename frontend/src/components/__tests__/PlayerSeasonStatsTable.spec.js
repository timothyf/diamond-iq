import { mount } from '@vue/test-utils'

import PlayerSeasonStatsTable from '../PlayerSeasonStatsTable.vue'

function buildProps(overrides = {}) {
  return {
    rows: [
      {
        id: 1,
        rank: 16,
        season: 2024,
        player: {
          full_name: 'Miguel Cabrera',
          mlb_id: 408234,
        },
        team: {
          abbreviation: 'DET',
          name: 'Detroit Tigers',
        },
        stats: {
          gamesPlayed: '150',
          homeRuns: '24',
          ops: '0.887',
        },
      },
    ],
    meta: {
      page: 2,
      totalPages: 3,
      totalCount: 25,
      dataRange: { type: 'season', start: 1970, end: 2026 },
      columns: [
        { key: 'gamesPlayed', label: 'G', align: 'numeric' },
        { key: 'homeRuns', label: 'HR', align: 'numeric' },
        { key: 'ops', label: 'OPS', align: 'numeric' },
      ],
    },
    loading: false,
    sort: '-homeRuns',
    ...overrides,
  }
}

describe('PlayerSeasonStatsTable', () => {
  it('renders the row data and metadata', () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps(),
    })

    expect(wrapper.text()).toContain('Page 2 of 3')
    expect(wrapper.text()).toContain('25 total matching players')
    expect(wrapper.text()).toContain('Data range: 1970-2026 seasons')
    expect(wrapper.text()).toContain('Miguel Cabrera')
    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('150')
    expect(wrapper.text()).toContain('24')
    expect(wrapper.text()).toContain('0.887')
  })

  it('emits sort-change when a column header is clicked', async () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({ sort: 'homeRuns' }),
    })

    const valueHeader = wrapper.findAll('th button').find((button) => button.text().includes('HR'))
    await valueHeader.trigger('click')

    expect(wrapper.emitted('sort-change')).toEqual([['-homeRuns']])
  })

  it('defaults a newly selected column sort to descending', async () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({ sort: '-homeRuns' }),
    })

    const valueHeader = wrapper.findAll('th button').find((button) => button.text().includes('OPS'))
    await valueHeader.trigger('click')

    expect(wrapper.emitted('sort-change')).toEqual([['-ops']])
  })

  it('adds an active class to the currently sorted column header', () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({ sort: '-homeRuns' }),
    })

    const sortedHeader = wrapper.findAll('th button').find((button) => button.text().includes('HR'))
    const unsortedHeader = wrapper.findAll('th button').find((button) => button.text().includes('OPS'))

    expect(sortedHeader.classes()).toContain('sort-button--active')
    expect(unsortedHeader.classes()).not.toContain('sort-button--active')
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

  it('removes decimal places from pitching count stats but preserves rate stats', () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({
        rows: [
          {
            id: 2,
            rank: 1,
            season: 2026,
            player: {
              full_name: 'Jacob Misiorowski',
              mlb_id: 694819,
            },
            team: {
              abbreviation: 'MIL',
              name: 'Milwaukee Brewers',
              short_name: 'Brewers',
            },
            stats: {
              W: '5.0',
              strikeOuts: '100.0',
              inningsPitched: '64.0',
              ERA: '1.83',
              whip: '0.83',
            },
          },
        ],
        meta: {
          page: 1,
          totalPages: 1,
          totalCount: 1,
          category: 'pitching',
          columns: [
            { key: 'W', label: 'W', align: 'numeric' },
            { key: 'strikeOuts', label: 'SO', align: 'numeric' },
            { key: 'inningsPitched', label: 'IP', align: 'numeric' },
            { key: 'ERA', label: 'ERA', align: 'numeric' },
            { key: 'whip', label: 'WHIP', align: 'numeric' },
          ],
        },
      }),
    })

    expect(wrapper.text()).toContain('5')
    expect(wrapper.text()).toContain('100')
    expect(wrapper.text()).toContain('64.0')
    expect(wrapper.text()).toContain('1.83')
    expect(wrapper.text()).toContain('0.83')
    expect(wrapper.text()).not.toContain('5.0')
    expect(wrapper.text()).not.toContain('100.0')
  })

  it('removes decimal places from batting count stats but preserves slash stats', () => {
    const wrapper = mount(PlayerSeasonStatsTable, {
      props: buildProps({
        rows: [
          {
            id: 3,
            rank: 1,
            season: 2026,
            player: {
              full_name: 'Spencer Torkelson',
              mlb_id: 679529,
            },
            team: {
              abbreviation: 'DET',
              name: 'Detroit Tigers',
              short_name: 'Tigers',
            },
            stats: {
              gamesPlayed: '56.0',
              atBats: '185.0',
              homeRuns: '8.0',
              strikeOuts: '70.0',
              avg: '0.205',
              obp: '0.31',
              slg: '.39',
              ops: '0.75',
            },
          },
        ],
        meta: {
          page: 1,
          totalPages: 1,
          totalCount: 1,
          category: 'batting',
          columns: [
            { key: 'gamesPlayed', label: 'G', align: 'numeric' },
            { key: 'atBats', label: 'AB', align: 'numeric' },
            { key: 'homeRuns', label: 'HR', align: 'numeric' },
            { key: 'strikeOuts', label: 'SO', align: 'numeric' },
            { key: 'avg', label: 'AVG', align: 'numeric' },
            { key: 'obp', label: 'OBP', align: 'numeric' },
            { key: 'slg', label: 'SLG', align: 'numeric' },
            { key: 'ops', label: 'OPS', align: 'numeric' },
          ],
        },
      }),
    })

    const valueCells = wrapper.findAll('tbody td.value-cell')

    expect(wrapper.text()).toContain('56')
    expect(wrapper.text()).toContain('185')
    expect(wrapper.text()).toContain('8')
    expect(wrapper.text()).toContain('70')
    expect(valueCells[4].text()).toBe('.205')
    expect(valueCells[5].text()).toBe('.310')
    expect(valueCells[6].text()).toBe('.390')
    expect(valueCells[7].text()).toBe('.750')
    expect(wrapper.text()).not.toContain('56.0')
    expect(wrapper.text()).not.toContain('185.0')
    expect(wrapper.text()).not.toContain('8.0')
    expect(wrapper.text()).not.toContain('70.0')
  })
})

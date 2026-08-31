import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'

import RecentTeamHistoryCard from '../RecentTeamHistoryCard.vue'

const RouterLinkStub = {
  props: ['to'],
  template: '<a><slot /></a>',
}

describe('RecentTeamHistoryCard', () => {
  it('renders every player in a grouped trade package with available profile links', () => {
    const player = {
      profile: {
        draftYear: 2021,
        draftRound: 1,
        draftRoundPickNumber: 3,
        draftPickNumber: 220,
        draftTeam: { name: 'San Diego Padres' },
        awards: [],
        allStarSelections: [2026],
        mlbDebutDate: '2024-07-01',
      },
      teamHistory: [],
      trades: [
        {
          id: 1,
          occurredOn: '2022-08-02',
          description: 'Washington Nationals traded Juan Soto and Josh Bell to San Diego Padres for six players.',
          sides: [
            {
              team: { id: 1, mlbId: 135, name: 'San Diego Padres' },
              players: [
                { id: 10, mlbId: 665742, fullName: 'Juan Soto' },
                { id: null, mlbId: 605137, fullName: 'Josh Bell' },
              ],
            },
            {
              team: { id: 2, mlbId: 120, name: 'Washington Nationals' },
              players: [
                { id: 11, mlbId: 695578, fullName: 'James Wood' },
                { id: 12, mlbId: 682928, fullName: 'CJ Abrams' },
              ],
            },
          ],
        },
      ],
    }

    const wrapper = mount(RecentTeamHistoryCard, {
      global: {
        provide: {
          'player-profile-context': {
            player,
            formatDate: (value) => value,
            teamHistoryLabel: () => '',
          },
        },
        stubs: { RouterLink: RouterLinkStub },
      },
    })

    expect(wrapper.get('[data-test="trade-history"]').text()).toContain('Washington Nationals traded Juan Soto')
    expect(wrapper.text()).toContain('To San Diego Padres')
    expect(wrapper.text()).toContain('2021 MLB Draft · Round 1, Pick 3 (220) · San Diego Padres')
    expect(wrapper.text()).toContain('To Washington Nationals')
    expect(wrapper.text()).toContain('Juan Soto · Josh Bell')
    expect(wrapper.text()).toContain('James Wood · CJ Abrams')
    expect(wrapper.findAll('a').map((link) => link.text())).toEqual(
      expect.arrayContaining(['San Diego Padres', 'Washington Nationals', 'Juan Soto', 'James Wood', 'CJ Abrams']),
    )
  })
})

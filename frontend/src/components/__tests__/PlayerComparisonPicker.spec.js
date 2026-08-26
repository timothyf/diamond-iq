import { mount } from '@vue/test-utils'

import PlayerComparisonPicker from '../PlayerComparisonPicker.vue'

describe('PlayerComparisonPicker', () => {
  it('keeps the selected slot visible while the profile is loading', () => {
    const wrapper = mount(PlayerComparisonPicker, {
      props: {
        label: 'Player A',
        selectedPlayerId: 7,
        profileLoading: true,
      },
    })

    expect(wrapper.text()).toContain('Loading player…')
    expect(wrapper.text()).toContain('Loading player profile…')
    expect(wrapper.get('button').text()).toBe('Change')
  })

  it('shows the selected player and loading status when a profile refresh is pending', () => {
    const wrapper = mount(PlayerComparisonPicker, {
      props: {
        label: 'Player A',
        selectedPlayerId: 7,
        selectedPlayer: {
          id: 7,
          fullName: 'Luis Arraez',
          firstName: 'Luis',
          lastName: 'Arraez',
          team: { name: 'San Diego Padres' },
          positions: { primary: { abbreviation: '1B' } },
          profile: { age: 29, bats: 'L', throws: 'R' },
        },
        profileLoading: true,
      },
    })

    expect(wrapper.text()).toContain('Luis Arraez')
    expect(wrapper.text()).toContain('Loading player profile…')
  })
})

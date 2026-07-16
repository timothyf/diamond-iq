import { mount } from '@vue/test-utils'

afterEach(() => {
  document.body.innerHTML = ''
})

import PlayerTrendChart from '../PlayerTrendChart.vue'

describe('PlayerTrendChart', () => {
  const series = [
    {
      key: 'exit_velocity',
      label: 'Exit velocity',
      points: [
        { date: '2026-04-01', sequence: 1, value: 89.0, sample_size: 4 },
        { date: '2026-04-08', sequence: 2, value: 91.2, sample_size: 6 },
      ],
    },
  ]

  it('shows tooltip value and date when hovering the trend line area', async () => {
    const wrapper = mount(PlayerTrendChart, {
      attachTo: document.body,
      props: {
        title: 'Batting · Exit velocity',
        subtitle: 'Rolling 50 plate appearances',
        unit: 'mph',
        series,
      },
    })

    const svg = wrapper.get('svg')
    svg.element.getBoundingClientRect = () => ({
      left: 0,
      top: 0,
      width: 720,
      height: 260,
      right: 720,
      bottom: 260,
      x: 0,
      y: 0,
      toJSON: () => ({}),
    })

    const inspector = wrapper.get('[data-test="trend-inspector"]')
    expect(inspector.text()).toContain('91.2 mph')
    expect(inspector.text()).toContain('Apr 8, 2026')

    await svg.trigger('mousemove', { clientX: 54, clientY: 202 })

    expect(inspector.text()).toContain('89.0 mph')
    expect(inspector.text()).toContain('Apr 1, 2026')
    expect(inspector.text()).toContain('Sample 4')
    expect(wrapper.find('.trend-chart__crosshair').exists()).toBe(true)
  })

  it('shows tooltip value and date when focusing a chart point', async () => {
    const wrapper = mount(PlayerTrendChart, {
      attachTo: document.body,
      props: {
        title: 'Batting · Exit velocity',
        subtitle: 'Rolling 50 plate appearances',
        unit: 'mph',
        series,
      },
    })

    const hitAreas = wrapper.findAll('.trend-chart__point-hit')
    await hitAreas[1].trigger('focus')

    const inspector = wrapper.get('[data-test="trend-inspector"]')
    expect(inspector.text()).toContain('91.2 mph')
    expect(inspector.text()).toContain('Apr 8, 2026')
    expect(inspector.text()).toContain('Sample 6')
  })
})

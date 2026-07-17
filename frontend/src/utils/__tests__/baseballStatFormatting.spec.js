import { describe, expect, it } from 'vitest'

import { formatBaseballStatValue, formatTwoDecimalPitchingRate } from '../baseballStatFormatting'

describe('baseball stat formatting', () => {
  it('rounds ERA and WHIP to exactly two decimal places', () => {
    expect(formatBaseballStatValue('ERA', '3.8126')).toBe('3.81')
    expect(formatBaseballStatValue('whip', 1.236)).toBe('1.24')
    expect(formatTwoDecimalPitchingRate(4)).toBe('4.00')
  })

  it('does not change unrelated stat values', () => {
    expect(formatBaseballStatValue('ops', '0.842')).toBe('0.842')
  })
})

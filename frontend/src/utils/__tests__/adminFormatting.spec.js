import { describe, expect, it } from 'vitest'

import {
  formatBytes,
  formatCount,
  formatDate,
  formatDuration,
  formatDurationRangeSeconds,
  formatDurationSeconds,
  formatElapsed,
  formatTimestamp,
  humanize,
  inclusiveDayCount,
} from '../adminFormatting'

describe('adminFormatting', () => {
  it('formats dates and timestamps with explicit fallbacks', () => {
    expect(formatDate('2026-07-19')).toBe('Jul 19, 2026')
    expect(formatDate(null)).toBe('Unavailable')
    expect(formatDate(null, '—')).toBe('—')
    expect(formatTimestamp('2026-07-19T12:00:00Z')).toContain('2026')
    expect(formatTimestamp(null, '')).toBe('')
  })

  it('formats byte sizes and counts', () => {
    expect(formatBytes(0)).toBe('0 B')
    expect(formatBytes(536_870_912)).toBe('512 MB')
    expect(formatBytes(1_610_612_736)).toBe('1.50 GB')
    expect(formatBytes(-1)).toBe('Unavailable')
    expect(formatCount(4_649_481)).toBe('4,649,481')
    expect(formatCount(undefined)).toBe('Unavailable')
  })

  it('formats durations and elapsed task time', () => {
    expect(formatDuration(1)).toBe('1 minute')
    expect(formatDuration(90)).toBe('1 hr 30 min')
    expect(formatDurationSeconds(1326)).toBe('22 minutes')
    expect(formatDurationRangeSeconds(1061, 1724)).toBe('18–29 minutes')
    expect(formatElapsed(252)).toBe('4m 12s')
    expect(formatElapsed(null)).toBe('Calculating…')
  })

  it('humanizes labels and counts inclusive calendar days', () => {
    expect(humanize('mlb_schedule_sync')).toBe('Mlb Schedule Sync')
    expect(inclusiveDayCount('2026-07-01', '2026-07-07')).toBe(7)
  })
})

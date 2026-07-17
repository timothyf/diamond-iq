const TWO_DECIMAL_PITCHING_RATE_KEYS = new Set(['era', 'whip'])

export function isTwoDecimalPitchingRate(statKey) {
  return TWO_DECIMAL_PITCHING_RATE_KEYS.has(String(statKey || '').trim().toLowerCase())
}

export function formatTwoDecimalPitchingRate(value) {
  if (value === null || value === undefined || value === '') return '—'

  const numericValue = Number(value)
  return Number.isFinite(numericValue) ? numericValue.toFixed(2) : value
}

export function formatBaseballStatValue(statKey, value) {
  if (value === null || value === undefined || value === '') return '—'
  if (isTwoDecimalPitchingRate(statKey)) return formatTwoDecimalPitchingRate(value)

  return value
}

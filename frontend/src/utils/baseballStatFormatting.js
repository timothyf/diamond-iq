const TWO_DECIMAL_PITCHING_RATE_KEYS = new Set(['era', 'whip'])
const ONE_DECIMAL_KEYS = new Set(['war'])

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
  if (ONE_DECIMAL_KEYS.has(String(statKey || '').trim().toLowerCase())) {
    const numericValue = Number(value)
    return Number.isFinite(numericValue) ? numericValue.toFixed(1) : value
  }

  return value
}

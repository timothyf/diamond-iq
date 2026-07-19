export function humanize(value) {
  return String(value || '').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

export function formatDate(value, fallback = 'Unavailable') {
  if (!value) return fallback
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${value}T12:00:00`))
}

export function formatTimestamp(value, fallback = 'Unavailable', includeYear = true) {
  if (!value) return fallback
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    ...(includeYear ? { year: 'numeric' } : {}),
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value))
}

export function formatBytes(value) {
  if (!Number.isFinite(value) || value < 0) return 'Unavailable'

  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let amount = value
  let unitIndex = 0
  while (amount >= 1024 && unitIndex < units.length - 1) {
    amount /= 1024
    unitIndex += 1
  }

  const precision = unitIndex < 2 || amount >= 100 ? 0 : amount >= 10 ? 1 : 2
  return `${amount.toFixed(precision)} ${units[unitIndex]}`
}

export function formatCount(value) {
  if (!Number.isFinite(value)) return 'Unavailable'
  return new Intl.NumberFormat('en-US').format(value)
}

export function inclusiveDayCount(startDate, endDate) {
  const start = new Date(`${startDate}T12:00:00Z`)
  const end = new Date(`${endDate}T12:00:00Z`)
  return Math.max(1, Math.round((end - start) / 86_400_000) + 1)
}

export function formatDuration(minutes) {
  if (minutes < 60) return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'}`

  const hours = Math.floor(minutes / 60)
  const remainingMinutes = minutes % 60
  return `${hours} hr${remainingMinutes ? ` ${remainingMinutes} min` : ''}`
}

export function formatDurationRange(lowMinutes, highMinutes) {
  if (highMinutes < 60) return `${lowMinutes}–${highMinutes} minutes`
  return `${formatDuration(lowMinutes)}–${formatDuration(highMinutes)}`
}

export function formatDurationSeconds(seconds) {
  const roundedMinutes = Math.max(1, Math.round(seconds / 60))
  return formatDuration(roundedMinutes)
}

export function formatDurationRangeSeconds(lowSeconds, highSeconds) {
  const lowMinutes = Math.max(1, Math.round(lowSeconds / 60))
  const highMinutes = Math.max(lowMinutes, Math.round(highSeconds / 60))
  return formatDurationRange(lowMinutes, highMinutes)
}

export function formatElapsed(seconds) {
  if (!Number.isFinite(seconds)) return 'Calculating…'
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  return `${minutes}m${remainingSeconds ? ` ${remainingSeconds}s` : ''}`
}

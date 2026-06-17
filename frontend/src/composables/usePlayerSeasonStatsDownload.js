import { computed, ref } from 'vue'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function buildSuccessMessage(payload) {
  const data = payload.data || {}
  const messageParts = [payload.message].filter(Boolean)

  if (typeof data.downloaded_count === 'number') {
    messageParts.push(`Downloaded ${data.downloaded_count} MLB rows.`)
  }

  if (data.replace_season && typeof data.replaced_rows_count === 'number') {
    messageParts.push(`Replaced ${data.replaced_rows_count} existing season rows before import.`)
  }

  if (typeof data.skipped_count === 'number' && data.skipped_count > 0) {
    messageParts.push(`Skipped ${data.skipped_count} rows.`)
  }

  return messageParts.join(' ')
}

function buildErrorMessage(payload, status) {
  if (payload?.message) return payload.message
  return `MLB download failed with status ${status}.`
}

export function usePlayerSeasonStatsDownload() {
  const downloading = ref(false)
  const error = ref('')
  const summary = ref('')

  async function downloadStats(options = {}) {
    downloading.value = true
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/player_season_stats/download`, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          category: options.category,
          start_year: options.startYear,
          end_year: options.endYear,
          replace_season: options.replaceSeason ? '1' : '0',
        }),
      })

      const payload = await response.json()

      if (!response.ok) {
        throw new Error(buildErrorMessage(payload, response.status))
      }

      summary.value = buildSuccessMessage(payload)
      return payload
    } catch (downloadError) {
      summary.value = ''
      error.value = downloadError.message || 'Unable to download MLB stats.'
      console.error(downloadError)
      return null
    } finally {
      downloading.value = false
    }
  }

  return {
    downloading: computed(() => downloading.value),
    error: computed(() => error.value),
    summary: computed(() => summary.value),
    downloadStats,
  }
}

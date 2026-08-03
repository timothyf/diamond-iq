import { computed, ref } from 'vue'
import { adminRequestHeaders } from './apiAuth'
import { API_BASE_URL } from '../config'

function buildErrorMessage(payload, status) {
  if (payload?.message) return payload.message
  return `Pitch data download failed with status ${status}.`
}

function buildSuccessMessage(payload) {
  const data = payload.data || {}
  const messageParts = [payload.message].filter(Boolean)

  if (typeof data.downloaded_count === 'number') {
    messageParts.push(`Downloaded ${data.downloaded_count} Statcast rows.`)
  }

  if (typeof data.duplicate_count === 'number' && data.duplicate_count > 0) {
    messageParts.push(`Collapsed ${data.duplicate_count} duplicate pitch rows.`)
  }

  if (typeof data.skipped_count === 'number' && data.skipped_count > 0) {
    messageParts.push(`Skipped ${data.skipped_count} invalid rows.`)
  }

  return messageParts.join(' ')
}

export function usePitchDataDownload() {
  const downloading = ref(false)
  const error = ref('')
  const summary = ref('')

  async function downloadPitchData(options = {}) {
    downloading.value = true
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/pitch_data/download`, {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
          'Content-Type': 'application/json',
        }),
        body: JSON.stringify({
          start_date: options.startDate,
          end_date: options.endDate,
          game_types: options.gameTypes,
          chunk_days: options.chunkDays,
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
      error.value = downloadError.message || 'Unable to download pitch data.'
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
    downloadPitchData,
  }
}

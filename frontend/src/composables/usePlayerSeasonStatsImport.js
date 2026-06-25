import { computed, ref } from 'vue'
import { adminRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function buildSuccessMessage(payload) {
  const data = payload.data || {}
  const messageParts = [payload.message].filter(Boolean)

  if (typeof data.created_player_count === 'number' && typeof data.created_team_count === 'number') {
    messageParts.push(`Created ${data.created_player_count} players and ${data.created_team_count} teams.`)
  }

  if (typeof data.skipped_count === 'number' && data.skipped_count > 0) {
    messageParts.push(`Skipped ${data.skipped_count} rows.`)
  }

  if (data.replace_season && typeof data.replaced_rows_count === 'number') {
    messageParts.push(`Replaced ${data.replaced_rows_count} existing season rows before import.`)
  }

  return messageParts.join(' ')
}

function buildErrorMessage(payload, status) {
  if (payload?.message) return payload.message
  return `Import failed with status ${status}.`
}

export function usePlayerSeasonStatsImport() {
  const uploading = ref(false)
  const error = ref('')
  const summary = ref('')

  async function importFile(file, options = {}) {
    if (!file) {
      error.value = 'Choose a CSV file before starting the import.'
      summary.value = ''
      return null
    }

    uploading.value = true
    error.value = ''

    try {
      const formData = new FormData()
      formData.append('file', file)
      formData.append('replace_season', options.replaceSeason ? '1' : '0')

      const response = await fetch(`${API_BASE_URL}/api/player_season_stats/import`, {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
        }),
        body: formData,
      })

      const payload = await response.json()

      if (!response.ok) {
        throw new Error(buildErrorMessage(payload, response.status))
      }

      summary.value = buildSuccessMessage(payload)
      return payload
    } catch (uploadError) {
      summary.value = ''
      error.value = uploadError.message || 'Unable to import the CSV file.'
      console.error(uploadError)
      return null
    } finally {
      uploading.value = false
    }
  }

  return {
    uploading: computed(() => uploading.value),
    error: computed(() => error.value),
    summary: computed(() => summary.value),
    importFile,
  }
}

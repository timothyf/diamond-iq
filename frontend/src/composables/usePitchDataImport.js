import { computed, ref } from 'vue'
import { adminRequestHeaders } from './apiAuth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

function buildErrorMessage(payload, status) {
  if (payload?.message) return payload.message
  return `Import failed with status ${status}.`
}

function buildSuccessMessage(payload) {
  const data = payload.data || {}
  const messageParts = [payload.message].filter(Boolean)

  if (typeof data.duplicate_count === 'number' && data.duplicate_count > 0) {
    messageParts.push(`Collapsed ${data.duplicate_count} duplicate pitch rows.`)
  }

  if (typeof data.skipped_count === 'number' && data.skipped_count > 0) {
    messageParts.push(`Skipped ${data.skipped_count} invalid rows.`)
  }

  return messageParts.join(' ')
}

export function usePitchDataImport() {
  const uploading = ref(false)
  const error = ref('')
  const summary = ref('')

  async function importFile(file) {
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

      const response = await fetch(`${API_BASE_URL}/api/pitch_data/import`, {
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

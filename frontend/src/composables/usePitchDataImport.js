import { computed, ref } from 'vue'
import { adminRequestHeaders } from './apiAuth'
import { taskRunAttribution, useBackgroundTaskRun } from './useBackgroundTaskRun'

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
  const validationError = ref('')
  const backgroundTask = useBackgroundTaskRun('pitch_data_import')

  async function importFile(file) {
    if (!file) {
      validationError.value = 'Choose a CSV file before starting the import.'
      return null
    }

    validationError.value = ''

    const formData = new FormData()
    formData.append('file', file)

    return backgroundTask.start('/api/pitch_data/import', {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
        }),
        body: formData,
      })
  }

  return {
    uploading: computed(() => backgroundTask.starting.value || backgroundTask.active.value),
    error: computed(() => validationError.value || backgroundTask.error.value),
    summary: computed(() => {
      const result = backgroundTask.task.value?.resultData
      return backgroundTask.task.value?.status === 'completed'
        ? `${buildSuccessMessage(result)}${taskRunAttribution(backgroundTask.task.value)}`
        : backgroundTask.summary.value
    }),
    task: backgroundTask.task,
    loadLatest: backgroundTask.loadLatest,
    importFile,
  }
}

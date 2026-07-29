import { computed, ref } from 'vue'
import { adminRequestHeaders } from './apiAuth'
import { taskRunAttribution, useBackgroundTaskRun } from './useBackgroundTaskRun'

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

export function usePlayerSeasonStatsImport() {
  const validationError = ref('')
  const backgroundTask = useBackgroundTaskRun('player_season_stats_import')

  async function importFile(file, options = {}) {
    if (!file) {
      validationError.value = 'Choose a CSV file before starting the import.'
      return null
    }

    validationError.value = ''

    const formData = new FormData()
    formData.append('file', file)
    formData.append('replace_season', options.replaceSeason ? '1' : '0')

    return backgroundTask.start('/api/player_season_stats/import', {
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

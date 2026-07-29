import { computed } from 'vue'
import { adminRequestHeaders } from './apiAuth'
import { taskRunAttribution, useBackgroundTaskRun } from './useBackgroundTaskRun'

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

export function usePlayerSeasonStatsDownload() {
  const backgroundTask = useBackgroundTaskRun('player_season_stats_download')

  async function downloadStats(options = {}) {
    return backgroundTask.start('/api/player_season_stats/download', {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
          'Content-Type': 'application/json',
        }),
        body: JSON.stringify({
          category: options.category,
          start_year: options.startYear,
          end_year: options.endYear,
          replace_season: options.replaceSeason ? '1' : '0',
        }),
      })
  }

  return {
    downloading: computed(() => backgroundTask.starting.value || backgroundTask.active.value),
    error: backgroundTask.error,
    summary: computed(() => {
      const result = backgroundTask.task.value?.resultData
      return backgroundTask.task.value?.status === 'completed'
        ? `${buildSuccessMessage(result)}${taskRunAttribution(backgroundTask.task.value)}`
        : backgroundTask.summary.value
    }),
    task: backgroundTask.task,
    loadLatest: backgroundTask.loadLatest,
    downloadStats,
  }
}

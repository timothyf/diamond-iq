import { computed, nextTick, onMounted, ref, watch } from 'vue'

import { useGameDetailsSync } from './useGameDetailsSync'
import { usePitchDataSync } from './usePitchDataSync'

const FINISHED_STATUSES = ['completed', 'failed', 'cancelled']
const ACTIVE_STATUSES = ['queued', 'running']

export function useAdminSyncWorkflows({
  gameDetailsOptions,
  pitchOptions,
  loadOverview,
  runTask,
  gameDetailsSync = useGameDetailsSync(),
  pitchDataSync = usePitchDataSync(),
}) {
  const gameDetailsConfirmationOpen = ref(false)
  const gameDetailsSyncCard = ref(null)
  const pendingGameDetailsParameters = ref(null)
  const pendingGameDetailsEstimate = ref(null)
  const pitchDataConfirmationOpen = ref(false)
  const pitchDataSyncCard = ref(null)
  const pendingPitchDataParameters = ref(null)
  const pendingPitchDataEstimate = ref(null)

  const gameDetailsEstimate = computed(() => {
    const parameters = pendingGameDetailsParameters.value
    const estimate = pendingGameDetailsEstimate.value
    if (!parameters) return null

    const spanDays = parameters.mlb_game_id ? null : inclusiveDayCount(parameters.start_date, parameters.end_date)
    const historicalTiming = estimate?.estimateSource === 'historical'
    return {
      scope: parameters.mlb_game_id
        ? `MLB game ${parameters.mlb_game_id}`
        : `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
      estimatedGames: estimate?.gameCount ?? 0,
      duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
      range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
      assumption: historicalTiming
        ? historicalTimingAssumption(estimate)
        : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerGame ?? 50)} per stored game. It will improve as completed sync timings are recorded.`,
    }
  })

  const pitchDataEstimate = computed(() => {
    const parameters = pendingPitchDataParameters.value
    const estimate = pendingPitchDataEstimate.value
    if (!parameters) return null

    const spanDays = inclusiveDayCount(parameters.start_date, parameters.end_date)
    const historicalTiming = estimate?.estimateSource === 'historical'
    return {
      scope: `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
      estimatedGames: estimate?.gameCount ?? 0,
      duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
      range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
      assumption: historicalTiming
        ? historicalTimingAssumption(estimate)
        : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerGame ?? 45)} per stored game. It will improve as completed sync timings are recorded.`,
    }
  })

  onMounted(() => Promise.all([gameDetailsSync.loadActiveTask(), pitchDataSync.loadActiveTask()]))

  watch(
    () => gameDetailsSync.task.value?.status,
    (status, previousStatus) => refreshOverviewAfterCompletion(status, previousStatus, loadOverview),
  )

  watch(
    () => pitchDataSync.task.value?.status,
    (status, previousStatus) => refreshOverviewAfterCompletion(status, previousStatus, loadOverview),
  )

  async function requestPitchDataSync() {
    normalizeDateRange(pitchOptions)
    const parameters = {
      start_date: pitchOptions.startDate,
      end_date: pitchOptions.endDate,
      game_types: pitchOptions.gameTypes,
      chunk_days: pitchOptions.chunkDays,
    }
    const estimate = await pitchDataSync.estimate(parameters)
    if (!estimate) return

    pendingPitchDataParameters.value = parameters
    pendingPitchDataEstimate.value = estimate
    pitchDataConfirmationOpen.value = true
  }

  async function cancelPitchDataSync() {
    pitchDataConfirmationOpen.value = false
    pendingPitchDataParameters.value = null
    pendingPitchDataEstimate.value = null
    await nextTick()
    pitchDataSyncCard.value?.focusSyncButton()
  }

  async function confirmPitchDataSync() {
    const parameters = pendingPitchDataParameters.value
    if (!parameters) return

    pitchDataConfirmationOpen.value = false
    pendingPitchDataParameters.value = null
    pendingPitchDataEstimate.value = null
    await pitchDataSync.start(parameters)
  }

  async function requestGameDetailsSync() {
    normalizeDateRange(gameDetailsOptions)
    const parameters = {
      start_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.startDate,
      end_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.endDate,
      mlb_game_id: gameDetailsOptions.mlbGameId || null,
    }
    const estimate = await gameDetailsSync.estimate(parameters)
    if (!estimate) return

    pendingGameDetailsParameters.value = parameters
    pendingGameDetailsEstimate.value = estimate
    gameDetailsConfirmationOpen.value = true
  }

  async function cancelGameDetailsSync() {
    gameDetailsConfirmationOpen.value = false
    pendingGameDetailsParameters.value = null
    pendingGameDetailsEstimate.value = null
    await nextTick()
    gameDetailsSyncCard.value?.focusSyncButton()
  }

  async function confirmGameDetailsSync() {
    const parameters = pendingGameDetailsParameters.value
    if (!parameters) return

    gameDetailsConfirmationOpen.value = false
    pendingGameDetailsParameters.value = null
    pendingGameDetailsEstimate.value = null
    await gameDetailsSync.start(parameters)
  }

  async function refreshGameDetailsAnalytics() {
    const parameters = gameDetailsRefreshParameters(gameDetailsSync.task.value)
    if (!parameters) return

    const result = await runTask('daily_analytics_refresh', parameters)
    if (result) {
      await loadOverview()
      await gameDetailsSync.loadActiveTask()
    }
  }

  return {
    gameDetailsConfirmationOpen,
    gameDetailsSyncCard,
    gameDetailsEstimate,
    gameDetailsTask: gameDetailsSync.task,
    gameDetailsSyncActive: gameDetailsSync.active,
    gameDetailsSyncStarting: gameDetailsSync.starting,
    gameDetailsSyncEstimating: gameDetailsSync.estimating,
    gameDetailsSyncError: gameDetailsSync.error,
    cancelActiveGameDetailsSync: gameDetailsSync.cancel,
    requestGameDetailsSync,
    cancelGameDetailsSync,
    confirmGameDetailsSync,
    refreshGameDetailsAnalytics,
    pitchDataConfirmationOpen,
    pitchDataSyncCard,
    pitchDataEstimate,
    pitchDataTask: pitchDataSync.task,
    pitchDataSyncActive: pitchDataSync.active,
    pitchDataSyncStarting: pitchDataSync.starting,
    pitchDataSyncEstimating: pitchDataSync.estimating,
    pitchDataSyncError: pitchDataSync.error,
    cancelActivePitchDataSync: pitchDataSync.cancel,
    requestPitchDataSync,
    cancelPitchDataSync,
    confirmPitchDataSync,
  }
}

function refreshOverviewAfterCompletion(status, previousStatus, loadOverview) {
  if (FINISHED_STATUSES.includes(status) && ACTIVE_STATUSES.includes(previousStatus)) loadOverview()
}

function normalizeDateRange(options) {
  if (options.startDate && options.endDate && options.startDate > options.endDate) options.endDate = options.startDate
}

function historicalTimingAssumption(estimate) {
  return `Based on ${formatCount(estimate.timingSampleGameCount)} completed game${estimate.timingSampleGameCount === 1 ? '' : 's'} across ${estimate.timingSampleRunCount} prior sync ${estimate.timingSampleRunCount === 1 ? 'run' : 'runs'} (${formatDurationSeconds(estimate.secondsPerGame)} per game).`
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${value}T12:00:00`))
}

function formatCount(value) {
  if (!Number.isFinite(value)) return 'Unavailable'
  return new Intl.NumberFormat('en-US').format(value)
}

function inclusiveDayCount(startDate, endDate) {
  const start = new Date(`${startDate}T12:00:00Z`)
  const end = new Date(`${endDate}T12:00:00Z`)
  return Math.max(1, Math.round((end - start) / 86_400_000) + 1)
}

function formatDuration(minutes) {
  if (minutes < 60) return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'}`

  const hours = Math.floor(minutes / 60)
  const remainingMinutes = minutes % 60
  return `${hours} hr${remainingMinutes ? ` ${remainingMinutes} min` : ''}`
}

function formatDurationRange(lowMinutes, highMinutes) {
  if (highMinutes < 60) return `${lowMinutes}–${highMinutes} minutes`
  return `${formatDuration(lowMinutes)}–${formatDuration(highMinutes)}`
}

function formatDurationSeconds(seconds) {
  const roundedMinutes = Math.max(1, Math.round(seconds / 60))
  return formatDuration(roundedMinutes)
}

function formatDurationRangeSeconds(lowSeconds, highSeconds) {
  const lowMinutes = Math.max(1, Math.round(lowSeconds / 60))
  const highMinutes = Math.max(lowMinutes, Math.round(highSeconds / 60))
  return formatDurationRange(lowMinutes, highMinutes)
}

function gameDetailsRefreshParameters(task) {
  if (!task?.taskParameters) return null
  const startDate = task.taskParameters.start_date
  const endDate = task.taskParameters.end_date || startDate
  if (!startDate || !endDate) return null

  return {
    start_date: startDate,
    end_date: endDate,
  }
}

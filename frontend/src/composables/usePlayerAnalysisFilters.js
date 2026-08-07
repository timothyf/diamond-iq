import { computed, ref, watch } from 'vue'

const RANGE_PRESETS = [
  { value: 'season', label: 'Full season' },
  { value: '7', label: 'Last 7 days' },
  { value: '14', label: 'Last 14 days' },
  { value: '30', label: 'Last 30 days' },
]

const VALID_RANGES = RANGE_PRESETS.map((preset) => preset.value).concat('custom')
const VALID_PA_WINDOWS = [25, 50, 100]
const VALID_PITCH_WINDOWS = [50, 100, 250]

export function usePlayerAnalysisFilters({ playerId, route, router, selectedPageTab }) {
  const analysisOptions = ref(readAnalysisOptions(route.query))
  const customStartDate = ref(route.query.start_date || '')
  const customEndDate = ref(route.query.end_date || '')
  const rangePresets = RANGE_PRESETS

  const savedAnalysisState = computed(() => ({ playerId: playerId.value, ...analysisOptions.value }))
  const savedAnalysisUrl = computed(() => {
    const options = analysisOptions.value
    const query = new URLSearchParams()
    if (options.range !== 'season') query.set('range', options.range)
    if (options.paWindow !== 50) query.set('pa_window', String(options.paWindow))
    if (options.pitchWindow !== 100) query.set('pitch_window', String(options.pitchWindow))
    if (options.range === 'custom' && options.startDate && options.endDate) {
      query.set('start_date', options.startDate)
      query.set('end_date', options.endDate)
    }
    return `/players/${encodeURIComponent(playerId.value)}${query.size ? `?${query}` : ''}`
  })

  watch(
    analysisOptions,
    (options) => {
      const query = {}
      if (selectedPageTab.value !== 'overview') query.view = selectedPageTab.value
      if (options.range !== 'season') query.range = options.range
      if (options.paWindow !== 50) query.pa_window = String(options.paWindow)
      if (options.pitchWindow !== 100) query.pitch_window = String(options.pitchWindow)
      if (options.range === 'custom' && options.startDate && options.endDate) {
        query.start_date = options.startDate
        query.end_date = options.endDate
      }
      router.replace({ name: 'player-profile', params: { id: playerId.value }, query })
    },
    { deep: true },
  )

  watch(
    () => [
      route.query.range,
      route.query.pa_window,
      route.query.pitch_window,
      route.query.start_date,
      route.query.end_date,
    ],
    ([range, paWindow, pitchWindow, startDate, endDate]) => {
      analysisOptions.value = readAnalysisOptions({ range, pa_window: paWindow, pitch_window: pitchWindow, start_date: startDate, end_date: endDate })
      customStartDate.value = startDate || ''
      customEndDate.value = endDate || ''
    },
  )

  function selectPreset(range) {
    analysisOptions.value = { ...analysisOptions.value, range, startDate: null, endDate: null }
  }

  function applyCustomRange() {
    if (!customStartDate.value || !customEndDate.value) return
    analysisOptions.value = {
      ...analysisOptions.value,
      range: 'custom',
      startDate: customStartDate.value,
      endDate: customEndDate.value,
    }
  }

  function updateWindow(key, value) {
    if (!['paWindow', 'pitchWindow'].includes(key)) return
    analysisOptions.value = { ...analysisOptions.value, [key]: Number(value) }
  }

  function openSavedAnalysis(item) {
    const state = item.state || {}
    analysisOptions.value = {
      range: state.range || 'season',
      paWindow: Number(state.paWindow || 50),
      pitchWindow: Number(state.pitchWindow || 100),
      startDate: state.startDate || null,
      endDate: state.endDate || null,
    }
    customStartDate.value = state.startDate || ''
    customEndDate.value = state.endDate || ''
    router.push(item.reproducibleUrl)
  }

  return {
    analysisOptions,
    customStartDate,
    customEndDate,
    rangePresets,
    savedAnalysisState,
    savedAnalysisUrl,
    selectPreset,
    applyCustomRange,
    updateWindow,
    openSavedAnalysis,
  }
}

function readAnalysisOptions(query = {}) {
  return {
    range: VALID_RANGES.includes(query.range) ? query.range : 'season',
    paWindow: VALID_PA_WINDOWS.includes(Number(query.pa_window)) ? Number(query.pa_window) : 50,
    pitchWindow: VALID_PITCH_WINDOWS.includes(Number(query.pitch_window)) ? Number(query.pitch_window) : 100,
    startDate: query.start_date || null,
    endDate: query.end_date || null,
  }
}

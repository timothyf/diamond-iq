import { computed, ref, watch } from 'vue'
import { API_BASE_URL, frontendConfig } from '../config'

const DEFAULT_PER_PAGE = frontendConfig.defaultPitchDataPerPage

function buildSearchParams(query) {
  const searchParams = new URLSearchParams()

  if (query.page) searchParams.set('page', String(query.page))
  if (query.perPage) searchParams.set('per_page', String(query.perPage))
  if (query.limit) searchParams.set('limit', String(query.limit))
  if (query.gameDateStart) searchParams.set('game_date_start', String(query.gameDateStart))
  if (query.gameDateEnd) searchParams.set('game_date_end', String(query.gameDateEnd))
  if (query.gamePk) searchParams.set('game_pk', String(query.gamePk))
  if (query.pitcher) searchParams.set('pitcher', String(query.pitcher))
  if (query.batter) searchParams.set('batter', String(query.batter))
  if (query.pitchType) searchParams.set('pitch_type', String(query.pitchType))
  if (query.events) searchParams.set('events', String(query.events))

  return searchParams
}

function formatInningHalf(inningTopbot) {
  const normalized = String(inningTopbot || '').trim().toLowerCase()
  if (normalized === 'top') return 'Top'
  if (normalized === 'bot' || normalized === 'bottom') return 'Bot'
  return ''
}

function normalizeRow(row = {}, index = 0, query = {}) {
  const page = Number.isFinite(Number(query.page)) ? Number(query.page) : 1
  const perPage = Number.isFinite(Number(query.perPage || query.limit)) ? Number(query.perPage || query.limit) : DEFAULT_PER_PAGE
  const rankOffset = Math.max(page - 1, 0) * perPage
  const ballsValue = row.balls
  const strikesValue = row.strikes
  const hasCount = ballsValue !== null && ballsValue !== undefined && strikesValue !== null && strikesValue !== undefined
  const inningValue = row.inning ?? '—'
  const inningTopbot = row.inning_topbot || row.inningTopbot || ''
  const inningHalfLabel = formatInningHalf(inningTopbot)

  return {
    id: row.id,
    rank: rankOffset + index + 1,
    gameDate: row.game_date || row.gameDate || '—',
    gamePk: row.game_pk || row.gamePk,
    atBatNumber: row.at_bat_number || row.atBatNumber,
    pitchNumber: row.pitch_number || row.pitchNumber,
    pitcher: row.pitcher,
    pitcherName: row.pitcher_name || row.pitcherName || null,
    playerName: row.player_name || row.playerName || '—',
    batter: row.batter,
    batterName: row.batter_name || row.batterName || null,
    pitchType: row.pitch_type || row.pitchType || '—',
    releaseSpeed: row.release_speed ?? row.releaseSpeed ?? '—',
    releaseSpinRate: row.release_spin_rate ?? row.releaseSpinRate ?? '—',
    launchSpeed: row.launch_speed ?? row.launchSpeed ?? '—',
    launchAngle: row.launch_angle ?? row.launchAngle ?? '—',
    hitDistanceSc: row.hit_distance_sc ?? row.hitDistanceSc ?? '—',
    balls: ballsValue ?? '—',
    strikes: strikesValue ?? '—',
    count: hasCount ? `${ballsValue}-${strikesValue}` : '—',
    zone: row.zone ?? '—',
    inning: inningValue,
    inningTopbot,
    inningDisplay: inningHalfLabel && inningValue !== '—' ? `${inningHalfLabel} ${inningValue}` : inningValue,
    description: row.description || '—',
    events: row.events || '—',
    pitchName: row.pitch_name || row.pitchName || '—',
  }
}

function normalizeMeta(meta = {}, requestedPerPage = DEFAULT_PER_PAGE) {
  const safePerPage = Number.isFinite(Number(meta.per_page || meta.limit)) ? Number(meta.per_page || meta.limit) : requestedPerPage
  const safeCount = Number.isFinite(Number(meta.count)) ? Number(meta.count) : 0
  const safePage = Number.isFinite(Number(meta.page)) ? Number(meta.page) : 1
  const safeTotalPages = Number.isFinite(Number(meta.total_pages)) ? Number(meta.total_pages) : 1
  const safeTotalCount = Number.isFinite(Number(meta.total_count)) ? Number(meta.total_count) : safeCount
  const availableEvents = Array.isArray(meta.available_events) ? meta.available_events.filter(Boolean) : []
  const availablePitchTypes = Array.isArray(meta.available_pitch_types) ? meta.available_pitch_types.filter(Boolean) : []

  return {
    limit: safePerPage,
    perPage: safePerPage,
    page: safePage,
    totalPages: safeTotalPages,
    totalCount: safeTotalCount,
    count: safeCount,
    dataRange: meta.data_range || null,
    availableEvents,
    availablePitchTypes,
  }
}

export function usePitchData(queryRef, enabledRef = computed(() => true)) {
  const rows = ref([])
  const meta = ref(normalizeMeta())
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0

  async function load() {
    if (!enabledRef.value) {
      reset()
      return
    }

    const requestId = requestCounter + 1
    requestCounter = requestId
    loading.value = true
    error.value = ''

    try {
      const searchParams = buildSearchParams(queryRef.value)
      const response = await fetch(`${API_BASE_URL}/api/pitch_data?${searchParams.toString()}`, {
        headers: {
          Accept: 'application/json',
        },
      })

      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`)
      }

      const payload = await response.json()
      if (requestId !== requestCounter || !enabledRef.value) return

      const sourceRows = Array.isArray(payload.data) ? payload.data : []
      const normalizedRows = sourceRows.map((row, index) => normalizeRow(row, index, queryRef.value || {}))

      rows.value = normalizedRows
      meta.value = normalizeMeta(payload.meta, queryRef.value?.perPage || queryRef.value?.limit || DEFAULT_PER_PAGE)
    } catch (fetchError) {
      if (requestId !== requestCounter || !enabledRef.value) return

      rows.value = []
      meta.value = normalizeMeta({}, queryRef.value?.perPage || queryRef.value?.limit || DEFAULT_PER_PAGE)
      error.value = 'Unable to load pitch data. Confirm the Rails API is running and reachable from the frontend.'
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  function reset() {
    requestCounter += 1
    rows.value = []
    meta.value = normalizeMeta({}, queryRef.value?.perPage || queryRef.value?.limit || DEFAULT_PER_PAGE)
    loading.value = false
    error.value = ''
  }

  watch(
    [queryRef, enabledRef],
    ([, enabled]) => {
      enabled ? load() : reset()
    },
    { deep: true, immediate: true },
  )

  return {
    rows: computed(() => rows.value),
    meta: computed(() => meta.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}

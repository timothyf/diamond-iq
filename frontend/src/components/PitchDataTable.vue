<script setup>
import { computed } from 'vue'

const emit = defineEmits(['page-change'])

const props = defineProps({
  rows: {
    type: Array,
    required: true,
  },
  meta: {
    type: Object,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
})

const currentPage = computed(() => Number(props.meta.page || 1))
const totalPages = computed(() => Number(props.meta.totalPages || 1))
const outerZones = [11, 12, 13, 14]
const innerZones = [1, 2, 3, 4, 5, 6, 7, 8, 9]

function normalizeZone(zone) {
  const parsedZone = Number(zone)
  return Number.isInteger(parsedZone) && parsedZone >= 1 && parsedZone <= 14 ? parsedZone : null
}

function selectedZoneClass(zone) {
  const normalizedZone = normalizeZone(zone)
  return normalizedZone ? `selected-${normalizedZone}` : ''
}

function goToPreviousPage() {
  if (currentPage.value <= 1 || props.loading) return

  emit('page-change', currentPage.value - 1)
}

function goToFirstPage() {
  if (currentPage.value <= 1 || props.loading) return

  emit('page-change', 1)
}

function goToNextPage() {
  if (currentPage.value >= totalPages.value || props.loading) return

  emit('page-change', currentPage.value + 1)
}

function goToLastPage() {
  if (currentPage.value >= totalPages.value || props.loading) return

  emit('page-change', totalPages.value)
}
</script>

<template>
  <div class="data-grid-shell">
    <div class="table-meta">
      <span>Showing {{ meta.count || 0 }} of {{ meta.totalCount || meta.count || 0 }} pitch rows</span>
      <span>Page {{ meta.page || 1 }} of {{ meta.totalPages || 1 }} · {{ meta.perPage || meta.limit || 50 }} per page</span>
    </div>

    <div class="table-meta">
      <button class="ghost-button" type="button" :disabled="loading || (meta.page || 1) <= 1" @click="goToFirstPage">
        First
      </button>
      <button class="ghost-button" type="button" :disabled="loading || (meta.page || 1) <= 1" @click="goToPreviousPage">
        Previous
      </button>
      <button class="ghost-button" type="button" :disabled="loading || (meta.page || 1) >= (meta.totalPages || 1)" @click="goToNextPage">
        Next
      </button>
      <button class="ghost-button" type="button" :disabled="loading || (meta.page || 1) >= (meta.totalPages || 1)" @click="goToLastPage">
        Last
      </button>
    </div>

    <div class="data-grid">
      <table>
        <thead>
          <tr>
            <th>Game</th>
            <th>Pitch</th>
            <th>Count</th>
            <th>Velo (MPH)</th>
            <th>Spin Rate</th>
            <th>Pitcher</th>
            <th>Batter</th>
            <th>EV (MPH)</th>
            <th>LA (°dd)</th>
            <th>Dist (ft)</th>
            <th>Zone</th>
            <th>Inning</th>
            <th>Description</th>
            <th>Events</th>
          </tr>
        </thead>

        <tbody v-if="rows.length">
          <tr v-for="row in rows" :key="row.id">
            <td class="value-cell game-cell">
              <span class="game-pk">{{ row.gamePk || '—' }}</span>
              <span class="game-date">{{ row.gameDate }}</span>
            </td>
            <td class="value-cell">{{ row.pitchType }}</td>
            <td class="value-cell">{{ row.count }}</td>
            <td class="value-cell">{{ row.releaseSpeed }}</td>
            <td class="value-cell">{{ row.releaseSpinRate }}</td>
            <td class="value-cell">{{ row.pitcherName || row.pitcher || '—' }}</td>
            <td class="value-cell">{{ row.batterName || row.batter || '—' }}</td>
            <td class="value-cell">{{ row.launchSpeed }}</td>
            <td class="value-cell">{{ row.launchAngle }}</td>
            <td class="value-cell">{{ row.hitDistanceSc }}</td>
            <td class="value-cell zone-cell">
              <template v-if="normalizeZone(row.zone)">
                <span class="hide">{{ normalizeZone(row.zone) }}</span>
                <div class="zone-icon" :class="selectedZoneClass(row.zone)" :title="`Zone ${normalizeZone(row.zone)}`">
                  <div class="outer-zone">
                    <div v-for="outerZone in outerZones" :key="`outer-${row.id}-${outerZone}`" :class="`zone-${outerZone}`"></div>
                  </div>
                  <div class="inner-zone">
                    <div v-for="innerZone in innerZones" :key="`inner-${row.id}-${innerZone}`" :class="`zone-${innerZone}`"></div>
                  </div>
                </div>
              </template>
              <span v-else>—</span>
            </td>
            <td class="value-cell">{{ row.inningDisplay || row.inning }}</td>
            <td class="value-cell">{{ row.description }}</td>
            <td class="value-cell">{{ row.events }}</td>
          </tr>
        </tbody>

        <tbody v-else>
          <tr>
            <td class="empty-state" colspan="14">
              <span v-if="loading">Loading pitch data…</span>
              <span v-else>No pitch rows have been imported yet.</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.hide {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
}

.zone-cell {
  text-align: right;
  vertical-align: middle;
}

.game-cell {
  min-width: 7.5rem;
  line-height: 1.2;
}

.game-pk,
.game-date {
  display: block;
}

.game-pk {
  font-weight: 600;
}

.game-date {
  font-size: 0.85em;
  opacity: 0.82;
}

.zone-icon {
  --zone-border: color-mix(in srgb, currentColor 45%, transparent);
  --zone-fill: color-mix(in srgb, currentColor 8%, transparent);
  --zone-active: color-mix(in srgb, #ff6f3c 85%, transparent);
  --zone-active-border: #ff6f3c;
  --zone-size: 40px;
  --inner-size: 24px;
  --outer-l-size: calc(var(--zone-size) / 2);
  --outer-thickness: calc((var(--zone-size) - var(--inner-size)) / 2);
  position: relative;
  display: inline-block;
  width: var(--zone-size);
  height: var(--zone-size);
}

.outer-zone {
  position: absolute;
  inset: 0;
}

.inner-zone {
  position: absolute;
  top: calc((var(--zone-size) - var(--inner-size)) / 2);
  left: calc((var(--zone-size) - var(--inner-size)) / 2);
  width: var(--inner-size);
  height: var(--inner-size);
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: repeat(3, 1fr);
  gap: 1px;
}

.outer-zone > div,
.inner-zone > div {
  background: var(--zone-fill);
  border: 1px solid var(--zone-border);
  border-radius: 2px;
}

.outer-zone > div {
  position: absolute;
  width: var(--outer-l-size);
  height: var(--outer-l-size);
}

.zone-11 {
  top: 0;
  left: 0;
  clip-path: polygon(0 0, 100% 0, 100% var(--outer-thickness), var(--outer-thickness) var(--outer-thickness), var(--outer-thickness) 100%, 0 100%);
}

.zone-12 {
  top: 0;
  right: 0;
  clip-path: polygon(0 0, 100% 0, 100% 100%, calc(100% - var(--outer-thickness)) 100%, calc(100% - var(--outer-thickness)) var(--outer-thickness), 0 var(--outer-thickness));
}

.zone-13 {
  bottom: 0;
  left: 0;
  clip-path: polygon(0 0, var(--outer-thickness) 0, var(--outer-thickness) calc(100% - var(--outer-thickness)), 100% calc(100% - var(--outer-thickness)), 100% 100%, 0 100%);
}

.zone-14 {
  right: 0;
  bottom: 0;
  clip-path: polygon(calc(100% - var(--outer-thickness)) 0, 100% 0, 100% 100%, 0 100%, 0 calc(100% - var(--outer-thickness)), calc(100% - var(--outer-thickness)) calc(100% - var(--outer-thickness)));
}

.zone-icon.selected-1 .zone-1,
.zone-icon.selected-2 .zone-2,
.zone-icon.selected-3 .zone-3,
.zone-icon.selected-4 .zone-4,
.zone-icon.selected-5 .zone-5,
.zone-icon.selected-6 .zone-6,
.zone-icon.selected-7 .zone-7,
.zone-icon.selected-8 .zone-8,
.zone-icon.selected-9 .zone-9,
.zone-icon.selected-11 .zone-11,
.zone-icon.selected-12 .zone-12,
.zone-icon.selected-13 .zone-13,
.zone-icon.selected-14 .zone-14 {
  background: var(--zone-active);
  border-color: var(--zone-active-border);
}
</style>

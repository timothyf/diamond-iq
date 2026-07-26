<script setup>
import { computed, ref } from 'vue'

import { usePlayerSuggestions } from '../composables/usePlayerSuggestions'

const props = defineProps({
  label: { type: String, required: true },
  selectedPlayer: { type: Object, default: null },
  excludedPlayerId: { type: [String, Number], default: null },
})
const emit = defineEmits(['select', 'clear'])

const query = ref('')
const searchQuery = computed(() => ({ name: query.value, perPage: 6 }))
const { suggestions, loading, error } = usePlayerSuggestions(searchQuery)
const availableSuggestions = computed(() =>
  suggestions.value.filter((player) => String(player.id) !== String(props.excludedPlayerId)),
)

function choose(player) {
  emit('select', player)
  query.value = ''
}
</script>

<template>
  <section class="comparison-picker" :data-test="`comparison-picker-${label.toLowerCase()}`">
    <header><span>{{ label }}</span><button v-if="selectedPlayer" type="button" @click="emit('clear')">Change</button></header>
    <div v-if="selectedPlayer" class="comparison-picker__selected">
      <img v-if="selectedPlayer.profile?.headshotUrl" :src="selectedPlayer.profile.headshotUrl" :alt="`${selectedPlayer.fullName} headshot`" />
      <span v-else>{{ selectedPlayer.firstName?.[0] }}{{ selectedPlayer.lastName?.[0] }}</span>
      <div><strong>{{ selectedPlayer.fullName }}</strong><small>{{ selectedPlayer.displayTeam?.name || selectedPlayer.team?.name || 'Team unavailable' }}</small></div>
    </div>
    <div v-else class="comparison-picker__search">
      <label>
        <span class="visually-hidden">Search for {{ label.toLowerCase() }}</span>
        <input v-model="query" type="search" autocomplete="off" :placeholder="`Search ${label.toLowerCase()}…`" />
      </label>
      <p v-if="loading">Searching…</p>
      <p v-else-if="error">{{ error }}</p>
      <ul v-else-if="availableSuggestions.length">
        <li v-for="player in availableSuggestions" :key="player.id">
          <button type="button" @click="choose(player)">
            <strong>{{ player.fullName }}</strong>
            <small>{{ player.team?.abbreviation || '—' }} · MLB {{ player.mlbId }}</small>
          </button>
        </li>
      </ul>
      <p v-else-if="query.trim().length >= 2">No matching players.</p>
    </div>
  </section>
</template>

<style scoped>
.comparison-picker { min-width: 0; padding: 1rem; border: 1px solid rgba(16,38,61,.12); border-radius: 18px; background: rgba(255,255,255,.72); }
.comparison-picker > header { display: flex; justify-content: space-between; gap: .5rem; align-items: center; margin-bottom: .75rem; }
.comparison-picker > header span { color: #a93627; font-size: .68rem; font-weight: 900; letter-spacing: .12em; text-transform: uppercase; }
.comparison-picker > header button { padding: 0; border: 0; color: #6b7780; background: none; font-size: .68rem; font-weight: 800; cursor: pointer; }
.comparison-picker__selected { display: flex; gap: .8rem; align-items: center; min-height: 74px; }
.comparison-picker__selected > img,.comparison-picker__selected > span { display: grid; flex: 0 0 auto; width: 64px; height: 64px; place-items: center; border-radius: 50%; background: #dce4e8; object-fit: cover; font-weight: 900; }
.comparison-picker__selected strong,.comparison-picker__selected small { display: block; }
.comparison-picker__selected strong { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.35rem; text-transform: uppercase; }
.comparison-picker__selected small { margin-top: .15rem; color: #6a7882; }
.comparison-picker__search { position: relative; }
.comparison-picker__search input { width: 100%; padding: .72rem .8rem; border: 1px solid rgba(16,38,61,.18); border-radius: 11px; background: #fff; font: inherit; }
.comparison-picker__search p { margin: .5rem 0 0; color: #6a7882; font-size: .72rem; }
.comparison-picker__search ul { position: absolute; z-index: 5; top: calc(100% + .35rem); left: 0; width: 100%; margin: 0; padding: .35rem; border: 1px solid rgba(16,38,61,.15); border-radius: 12px; background: #fff; box-shadow: 0 12px 30px rgba(16,38,61,.14); list-style: none; }
.comparison-picker__search li button { display: flex; justify-content: space-between; gap: .7rem; width: 100%; padding: .65rem; border: 0; border-radius: 8px; background: transparent; text-align: left; cursor: pointer; }
.comparison-picker__search li button:hover { background: #eef2f4; }
.comparison-picker__search li strong,.comparison-picker__search li small { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.comparison-picker__search li small { color: #6b7881; }
</style>

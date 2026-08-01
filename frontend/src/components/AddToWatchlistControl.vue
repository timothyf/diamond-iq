<script setup>
import { computed, ref, watch } from 'vue'

import { authRequestHeaders } from '../composables/apiAuth'
import { useAuth } from '../composables/useAuth'

const props = defineProps({
  playerId: {
    type: [String, Number],
    required: true,
  },
  playerName: {
    type: String,
    required: true,
  },
})

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''
const { user } = useAuth()
const open = ref(false)
const watchlists = ref([])
const selectedWatchlistId = ref('')
const loading = ref(false)
const saving = ref(false)
const loaded = ref(false)
const error = ref('')
const success = ref('')

const availableWatchlists = computed(() => watchlists.value.filter((watchlist) => (
  !(watchlist.entries || []).some((entry) => Number(entry.player?.id) === Number(props.playerId))
)))

const selectedWatchlist = computed(() => watchlists.value.find(
  (watchlist) => Number(watchlist.id) === Number(selectedWatchlistId.value),
) || null)

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, options)
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(payload?.message || 'Unable to update this watchlist.')
  return payload?.data
}

async function loadWatchlists() {
  if (!user.value || loading.value) return

  loading.value = true
  error.value = ''
  try {
    watchlists.value = await request('/api/watchlists', {
      headers: authRequestHeaders({ Accept: 'application/json' }),
    }) || []
    loaded.value = true
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function toggle() {
  open.value = !open.value
  success.value = ''
  if (open.value && !loaded.value) await loadWatchlists()
}

async function addToWatchlist() {
  const watchlist = selectedWatchlist.value
  if (!watchlist) return

  saving.value = true
  error.value = ''
  success.value = ''
  try {
    const entry = await request(`/api/watchlists/${watchlist.id}/watchlist_entries`, {
      method: 'POST',
      headers: authRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ player_id: props.playerId }),
    })
    watchlist.entries = [...(watchlist.entries || []), entry]
    selectedWatchlistId.value = ''
    success.value = `${props.playerName} added to ${watchlist.name}.`
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    saving.value = false
  }
}

watch(user, (currentUser) => {
  if (!currentUser) {
    open.value = false
    watchlists.value = []
    selectedWatchlistId.value = ''
    loaded.value = false
    error.value = ''
    success.value = ''
  }
}, { immediate: true })

watch(() => props.playerId, () => {
  selectedWatchlistId.value = ''
  error.value = ''
  success.value = ''
})
</script>

<template>
  <div v-if="user" class="watchlist-control" data-test="add-to-watchlist-control">
    <button
      type="button"
      class="watchlist-control__trigger"
      :aria-expanded="open"
      aria-controls="player-watchlist-panel"
      @click="toggle"
    >
      Add to watchlist
      <span aria-hidden="true">+</span>
    </button>

    <div v-if="open" id="player-watchlist-panel" class="watchlist-control__panel">
      <strong>Add {{ playerName }}</strong>
      <p v-if="loading">Loading watchlists...</p>

      <form v-else-if="availableWatchlists.length" @submit.prevent="addToWatchlist">
        <label for="player-watchlist-select">Watchlist</label>
        <select id="player-watchlist-select" v-model="selectedWatchlistId" data-test="watchlist-select">
          <option value="" disabled>Choose a watchlist</option>
          <option v-for="watchlist in availableWatchlists" :key="watchlist.id" :value="String(watchlist.id)">
            {{ watchlist.name }}
          </option>
        </select>
        <button type="submit" :disabled="!selectedWatchlistId || saving" data-test="confirm-watchlist-add">
          {{ saving ? 'Adding...' : 'Add player' }}
        </button>
      </form>

      <p v-else-if="loaded && watchlists.length">
        {{ playerName }} is already on every accessible watchlist.
      </p>
      <p v-else-if="loaded">
        No watchlists are available.
        <RouterLink :to="{ name: 'watchlists' }">Create a watchlist</RouterLink>
      </p>

      <p v-if="success" class="watchlist-control__success" role="status">{{ success }}</p>
      <p v-if="error" class="watchlist-control__error" role="alert">{{ error }}</p>
    </div>
  </div>
</template>

<style scoped>
.watchlist-control {
  position: relative;
}

.watchlist-control__trigger {
  align-items: center;
  background: #17365f;
  border: 1px solid #17365f;
  border-radius: 999px;
  color: #fff;
  cursor: pointer;
  display: inline-flex;
  font: inherit;
  font-weight: 800;
  gap: 0.5rem;
  padding: 0.55rem 0.85rem;
}

.watchlist-control__trigger:hover,
.watchlist-control__trigger:focus-visible {
  background: #214d84;
  border-color: #214d84;
}

.watchlist-control__panel {
  background: #fff;
  border: 1px solid #cbd5e1;
  border-radius: 0.75rem;
  box-shadow: 0 16px 36px rgb(15 23 42 / 18%);
  color: #1f2937;
  min-width: 18rem;
  padding: 1rem;
  position: absolute;
  right: 0;
  top: calc(100% + 0.5rem);
  z-index: 20;
}

.watchlist-control__panel > strong {
  display: block;
  margin-bottom: 0.75rem;
}

.watchlist-control__panel form {
  display: grid;
  gap: 0.55rem;
}

.watchlist-control__panel label {
  font-size: 0.78rem;
  font-weight: 800;
}

.watchlist-control__panel select,
.watchlist-control__panel form button {
  border: 1px solid #b8c4d2;
  border-radius: 0.5rem;
  font: inherit;
  padding: 0.6rem 0.7rem;
}

.watchlist-control__panel form button {
  background: #0f766e;
  border-color: #0f766e;
  color: #fff;
  cursor: pointer;
  font-weight: 800;
}

.watchlist-control__panel form button:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.watchlist-control__panel p {
  font-size: 0.82rem;
  line-height: 1.45;
  margin: 0.65rem 0 0;
}

.watchlist-control__success {
  color: #08705f;
}

.watchlist-control__error {
  color: #b42318;
}

@media (max-width: 720px) {
  .watchlist-control__panel {
    left: 0;
    right: auto;
  }
}
</style>

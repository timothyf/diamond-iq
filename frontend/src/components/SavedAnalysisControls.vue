<script setup>
import { computed, onMounted, ref } from 'vue'

import { useAuth } from '../composables/useAuth'
import { useSavedAnalyses } from '../composables/useSavedAnalyses'

const props = defineProps({
  analysisType: { type: String, required: true },
  state: { type: Object, required: true },
  reproducibleUrl: { type: String, required: true },
  compact: { type: Boolean, default: false },
})
const emit = defineEmits(['apply'])
const { user } = useAuth()
const { items, loading, saving, error, load, create, update, remove } = useSavedAnalyses(props.analysisType)
const name = ref('')
const visibility = ref('private')
const copiedId = ref(null)
const canSave = computed(() => Boolean(user.value && name.value.trim() && props.reproducibleUrl))

onMounted(load)

async function saveCurrent() {
  if (!canSave.value) return
  const saved = await create({
    name: name.value.trim(),
    visibility: visibility.value,
    state: props.state,
    reproducibleUrl: props.reproducibleUrl,
  })
  if (saved) name.value = ''
}

async function changeVisibility(item, nextVisibility) {
  await update(item, { visibility: nextVisibility })
}

async function copyLink(item) {
  const url = new URL(item.shareUrl, window.location.origin).toString()
  await navigator.clipboard?.writeText(url)
  copiedId.value = item.id
  window.setTimeout(() => {
    if (copiedId.value === item.id) copiedId.value = null
  }, 1500)
}
</script>

<template>
  <section class="saved-analysis" :class="{ 'saved-analysis--compact': compact }" data-test="saved-analysis-controls">
    <header>
      <div><small>Saved analysis</small><strong>Views & sharing</strong></div>
      <span v-if="loading">Loading…</span>
    </header>

    <form v-if="user" @submit.prevent="saveCurrent">
      <input v-model="name" aria-label="Saved view name" placeholder="Name this view" required />
      <select v-model="visibility" aria-label="Saved view sharing">
        <option value="private">Private</option>
        <option value="organization">Organization</option>
        <option value="public">Public link</option>
      </select>
      <button type="submit" :disabled="!canSave || saving">{{ saving ? 'Saving…' : 'Save current' }}</button>
    </form>
    <p v-else class="saved-analysis__signin">Sign in to save this analysis. Publicly shared views remain available below.</p>

    <p v-if="error" class="saved-analysis__error" role="alert">{{ error }}</p>
    <div v-if="items.length" class="saved-analysis__list">
      <article v-for="item in items" :key="item.id">
        <button type="button" class="saved-analysis__open" @click="emit('apply', item)">
          <strong>{{ item.name }}</strong>
          <small>{{ item.owner?.name || 'Unknown owner' }} · {{ item.visibility }}</small>
        </button>
        <select
          v-if="item.editable"
          :value="item.visibility"
          :aria-label="`Sharing for ${item.name}`"
          @change="changeVisibility(item, $event.target.value)"
        >
          <option value="private">Private</option>
          <option value="organization">Organization</option>
          <option value="public">Public</option>
        </select>
        <button type="button" class="saved-analysis__link" @click="copyLink(item)">
          {{ copiedId === item.id ? 'Copied' : 'Copy link' }}
        </button>
        <button v-if="item.editable" type="button" class="saved-analysis__delete" @click="remove(item)">Delete</button>
      </article>
    </div>
    <p v-else-if="!loading" class="saved-analysis__empty">No saved views are visible for this analysis yet.</p>
  </section>
</template>

<style scoped>
.saved-analysis { margin: 1rem 0; padding: 1rem; border: 1px solid rgba(23,54,82,.16); border-radius: 16px; color: #173652; background: rgba(255,252,244,.88); }
.saved-analysis > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; }
.saved-analysis > header div { display: grid; }.saved-analysis > header small { color: #9a6c35; font-size: .62rem; font-weight: 900; letter-spacing: .08em; text-transform: uppercase; }
.saved-analysis > header strong { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.25rem; text-transform: uppercase; }
.saved-analysis form { display: grid; grid-template-columns: minmax(150px,1fr) 150px auto; gap: .45rem; margin-top: .65rem; }
.saved-analysis input,.saved-analysis select,.saved-analysis button { min-width: 0; padding: .55rem .65rem; border: 1px solid rgba(23,54,82,.18); border-radius: 9px; color: inherit; background: #fffdf8; font: inherit; }
.saved-analysis form button { border: 0; color: #fff; background: #20543c; font-weight: 850; }
.saved-analysis button { cursor: pointer; }.saved-analysis button:disabled { opacity: .55; cursor: not-allowed; }
.saved-analysis__list { display: grid; gap: .4rem; margin-top: .7rem; }
.saved-analysis__list article { display: grid; grid-template-columns: minmax(0,1fr) 130px auto auto; gap: .35rem; align-items: center; padding: .4rem; border-radius: 11px; background: rgba(23,54,82,.055); }
.saved-analysis__open { display: grid; text-align: left; }.saved-analysis__open small { color: #70808b; font-size: .65rem; text-transform: capitalize; }
.saved-analysis__link,.saved-analysis__delete { font-size: .67rem!important; font-weight: 850; }.saved-analysis__delete { color: #922e25!important; }
.saved-analysis__signin,.saved-analysis__empty { margin: .6rem 0 0; color: #6c7981; font-size: .73rem; }
.saved-analysis__error { margin: .6rem 0 0; color: #922e25; font-size: .75rem; font-weight: 800; }
.saved-analysis--compact { padding: .75rem; }
@media (max-width: 760px) { .saved-analysis form,.saved-analysis__list article { grid-template-columns: 1fr; } }
</style>

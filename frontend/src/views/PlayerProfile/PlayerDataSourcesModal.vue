<script setup>
import { nextTick, ref, watch } from 'vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  player: { type: Object, required: true },
  returnFocusEl: { type: Object, default: null },
})

const emit = defineEmits(['close'])
const modal = ref(null)

function titleize(value) {
  return String(value || '')
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value))
}

function close() {
  emit('close')
}

watch(
  () => props.open,
  async (open) => {
    if (open) {
      await nextTick()
      modal.value?.focus()
      return
    }

    await nextTick()
    props.returnFocusEl?.focus?.()
  },
)
</script>

<template>
  <div
    v-if="open"
    class="profile-modal-backdrop"
    data-test="player-data-provenance-modal"
    @click.self="close"
    @keydown.esc="close"
  >
    <section
      ref="modal"
      class="profile-modal profile-sources-modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="player-data-provenance-title"
      tabindex="-1"
    >
      <header class="profile-section-heading">
        <div>
          <p class="eyebrow">Data provenance</p>
          <h2 id="player-data-provenance-title">Sources & freshness</h2>
        </div>
        <button type="button" class="profile-modal__close" aria-label="Close data provenance" @click="close">×</button>
      </header>
      <p class="profile-modal__updated">Profile updated {{ formatTimestamp(player.sourceMetadata.lastUpdatedAt) }}</p>
      <div v-if="player.sourceMetadata.datasets.length" class="source-grid">
        <article v-for="dataset in player.sourceMetadata.datasets" :key="dataset.name">
          <strong>{{ titleize(dataset.name) }}</strong>
          <span>{{ dataset.sourceName || 'NineLens' }}</span>
          <small>{{ formatTimestamp(dataset.lastUpdatedAt) }}</small>
        </article>
      </div>
      <p v-else class="profile-empty">No source freshness details are available yet.</p>
    </section>
  </div>
</template>


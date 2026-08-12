<script setup>
import { computed, inject } from 'vue'

defineProps({
  activeTab: { type: String, required: true },
})

const emit = defineEmits(['tab-change'])
const context = inject('player-profile-context')
const player = context?.player

const pageTabs = computed(() => [
  { id: 'overview', label: 'Overview' },
  { id: 'performance-trends', label: 'Performance Trends' },
  { id: 'batted-ball-profile', label: 'Batted Ball Profile' },
  { id: 'similar-players', label: 'Similar Players' },
  ...(context?.canAccessNotes?.value ? [{ id: 'notes', label: 'Player Notes' }] : []),
  ...(player?.value?.pitchIndicators?.primaryRole === 'pitcher' ? [{ id: 'pitch-arsenal', label: 'Pitch Arsenal' }] : []),
])

function selectTab(tabId) {
  emit('tab-change', tabId)
}

function selectAdjacentTab(event, index) {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()

  let nextIndex = index
  if (event.key === 'ArrowRight') nextIndex = (index + 1) % pageTabs.value.length
  if (event.key === 'ArrowLeft') nextIndex = (index - 1 + pageTabs.value.length) % pageTabs.value.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = pageTabs.value.length - 1
  selectTab(pageTabs.value[nextIndex].id)
  event.currentTarget.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]')?.[nextIndex]?.focus()
}
</script>

<template>
  <nav class="profile-page-tabs" aria-label="Player profile pages">
    <div role="tablist">
      <button
        v-for="(tab, index) in pageTabs"
        :id="`player-page-tab-${tab.id}`"
        :key="tab.id"
        type="button"
        role="tab"
        :aria-controls="`player-page-panel-${tab.id}`"
        :aria-selected="activeTab === tab.id"
        :tabindex="activeTab === tab.id ? 0 : -1"
        :data-test="`player-page-tab-${tab.id}`"
        @click="selectTab(tab.id)"
        @keydown="selectAdjacentTab($event, index)"
      >
        {{ tab.label }}
      </button>
    </div>
  </nav>
</template>

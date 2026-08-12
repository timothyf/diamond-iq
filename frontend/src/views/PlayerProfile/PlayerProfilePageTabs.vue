<script setup>
defineProps({
  activeTab: { type: String, required: true },
})

const emit = defineEmits(['tab-change'])

const pageTabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'performance-trends', label: 'Performance Trends' },
  { id: 'batted-ball-profile', label: 'Batted Ball Profile' },
  { id: 'similar-players', label: 'Similar Players' },
]

function selectTab(tabId) {
  emit('tab-change', tabId)
}

function selectAdjacentTab(event, index) {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()

  let nextIndex = index
  if (event.key === 'ArrowRight') nextIndex = (index + 1) % pageTabs.length
  if (event.key === 'ArrowLeft') nextIndex = (index - 1 + pageTabs.length) % pageTabs.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = pageTabs.length - 1
  selectTab(pageTabs[nextIndex].id)
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

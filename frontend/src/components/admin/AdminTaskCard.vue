<script setup>
defineOptions({ inheritAttrs: false })

defineProps({
  as: { type: String, default: 'form' },
  number: { type: String, default: '' },
  source: { type: String, required: true },
  title: { type: String, required: true },
  chip: { type: String, default: '' },
  command: { type: String, default: '' },
  description: { type: String, default: '' },
  maintenance: { type: Boolean, default: false },
})
</script>

<template>
  <component :is="as" v-bind="$attrs" :class="['admin-card', { 'admin-card--maintenance': maintenance }]">
    <div v-if="number" class="admin-card__number">{{ number }}</div>
    <div class="admin-card__title">
      <div><p>{{ source }}</p><h3>{{ title }}</h3></div>
      <span v-if="chip" class="admin-chip">{{ chip }}</span>
      <code v-else-if="command">{{ command }}</code>
    </div>
    <p v-if="description" class="admin-card__description">{{ description }}</p>
    <slot />
  </component>
</template>

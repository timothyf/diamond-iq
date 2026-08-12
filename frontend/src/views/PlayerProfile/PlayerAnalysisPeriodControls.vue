<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  options: { type: Object, required: true },
  rangePresets: { type: Array, required: true },
  label: { type: String, default: 'Analysis period' },
})

const emit = defineEmits(['change'])
const customStartDate = ref(props.options.startDate || '')
const customEndDate = ref(props.options.endDate || '')

watch(() => props.options.startDate, (value) => { customStartDate.value = value || '' })
watch(() => props.options.endDate, (value) => { customEndDate.value = value || '' })

function selectPreset(range) {
  emit('change', { ...props.options, range, startDate: null, endDate: null })
}

function applyCustomRange() {
  if (!customStartDate.value || !customEndDate.value) return
  emit('change', {
    ...props.options,
    range: 'custom',
    startDate: customStartDate.value,
    endDate: customEndDate.value,
  })
}
</script>

<template>
  <section class="profile-panel analysis-controls" data-test="tab-analysis-period-controls">
    <div>
      <p class="eyebrow">{{ label }}</p>
      <div class="range-presets" role="group" :aria-label="label">
        <button
          v-for="preset in rangePresets"
          :key="preset.value"
          type="button"
          :class="{ 'is-active': options.range === preset.value }"
          @click="selectPreset(preset.value)"
        >
          {{ preset.label }}
        </button>
      </div>
    </div>
    <div class="custom-range">
      <label>From <input v-model="customStartDate" type="date" /></label>
      <label>Through <input v-model="customEndDate" type="date" /></label>
      <button type="button" :disabled="!customStartDate || !customEndDate" @click="applyCustomRange">Apply custom</button>
    </div>
  </section>
</template>

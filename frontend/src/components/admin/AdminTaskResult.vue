<script setup>
import { computed } from 'vue'
import { formatTimestamp, humanize } from '../../utils/adminFormatting'

const props = defineProps({
  error: { type: String, default: '' },
  result: { type: Object, default: null },
})

const resultEntries = computed(() => {
  const data = props.result?.data || {}
  return Object.entries(data)
    .filter(([, value]) => value !== null && value !== undefined && !Array.isArray(value) && typeof value !== 'object')
    .slice(0, 8)
})

</script>

<template>
  <div v-if="error" class="admin-result admin-result--error" role="alert">
    <strong>Task could not be completed</strong>
    <p>{{ error }}</p>
  </div>
  <div v-else-if="result" class="admin-result" data-test="task-result">
    <div>
      <p class="eyebrow">Latest task result</p>
      <h3>{{ result.message }}</h3>
      <small>{{ humanize(result.task) }} · {{ formatTimestamp(result.finishedAt, '', false) }}</small>
    </div>
    <dl v-if="resultEntries.length">
      <div v-for="([key, value]) in resultEntries" :key="key">
        <dt>{{ humanize(key) }}</dt>
        <dd>{{ value }}</dd>
      </div>
    </dl>
  </div>
</template>

<style scoped>
.admin-result {
  display: grid;
  gap: 1.25rem;
  grid-template-columns: minmax(240px, 0.8fr) minmax(0, 1.2fr);
  margin-top: 1rem;
  padding: 1.25rem;
  border: 1px solid rgba(49, 89, 67, 0.18);
  border-radius: 20px;
  background: #edf4ed;
}

.admin-result h3 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.45rem;
  line-height: 1.1;
}

.admin-result small {
  color: #66736b;
}

.admin-result dl {
  display: grid;
  gap: 0.55rem;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.admin-result dl div {
  padding: 0.65rem;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.68);
}

.admin-result dt {
  color: #68756d;
  font-size: 0.62rem;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.admin-result dd {
  color: #244531;
  font-size: 1.08rem;
  font-weight: 900;
}

.admin-result--error {
  display: block;
  color: #8f2d24;
  border-color: rgba(143, 45, 36, 0.2);
  background: #f7e7e3;
}

@media (max-width: 1000px) {
  .admin-result {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 680px) {
  .admin-result dl {
    grid-template-columns: 1fr;
  }
}
</style>

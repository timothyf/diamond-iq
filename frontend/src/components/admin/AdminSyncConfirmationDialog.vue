<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { formatCount } from '../../utils/adminFormatting'

const props = defineProps({
  open: { type: Boolean, default: false },
  testPrefix: { type: String, required: true },
  title: { type: String, required: true },
  estimate: { type: Object, default: null },
  note: { type: String, required: true },
})
const emit = defineEmits(['cancel', 'confirm'])
const dialog = ref(null)
const workloadSingular = computed(() => props.estimate?.workloadSingular || 'stored game')
const workloadPlural = computed(() => props.estimate?.workloadPlural || 'stored games')

watch(
  () => props.open,
  async (open) => {
    if (!open) return
    await nextTick()
    dialog.value?.focus()
  },
)

</script>

<template>
  <div
    v-if="open && estimate"
    class="confirmation-modal"
    :data-test="`${testPrefix}-confirmation-modal`"
    @click.self="emit('cancel')"
    @keydown.esc="emit('cancel')"
  >
    <section
      ref="dialog"
      class="confirmation-dialog"
      :data-test="`${testPrefix}-confirmation`"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="`${testPrefix}-confirmation-title`"
      :aria-describedby="`${testPrefix}-confirmation-description`"
      tabindex="-1"
    >
      <div class="confirmation-dialog__icon" aria-hidden="true">!</div>
      <p class="eyebrow">Before you continue</p>
      <h2 :id="`${testPrefix}-confirmation-title`">{{ title }}</h2>
      <p :id="`${testPrefix}-confirmation-description`">
        NineLens found
        <strong>{{ formatCount(estimate.estimatedGames) }} {{ estimate.estimatedGames === 1 ? workloadSingular : workloadPlural }}</strong>
        in <strong>{{ estimate.scope }}</strong>. Based on this selection, the operation should take
        <strong>{{ estimate.duration }}</strong> (typically {{ estimate.range }}).
      </p>
      <dl>
        <div>
          <dt>Estimated workload</dt>
          <dd>{{ formatCount(estimate.estimatedGames) }} {{ estimate.estimatedGames === 1 ? workloadSingular : workloadPlural }}</dd>
        </div>
        <div><dt>How this estimate works</dt><dd>{{ estimate.assumption }}</dd></div>
      </dl>
      <p class="confirmation-dialog__note">{{ note }}</p>
      <div class="confirmation-dialog__actions">
        <button type="button" class="admin-button admin-button--secondary" :data-test="`${testPrefix}-cancel`" @click="emit('cancel')">Cancel</button>
        <button type="button" class="admin-button" :data-test="`${testPrefix}-continue`" @click="emit('confirm')">Continue synchronization</button>
      </div>
    </section>
  </div>
</template>

<style>
.confirmation-modal { position: fixed; z-index: 100; inset: 0; display: grid; place-items: center; padding: 1rem; background: rgba(8,22,35,.7); backdrop-filter: blur(5px); }
.confirmation-dialog { width: min(620px, calc(100vw - 2rem)); padding: clamp(1.35rem, 4vw, 2rem); outline: none; border: 1px solid rgba(143,45,36,.2); border-radius: 24px; background: #fffaf0; box-shadow: 0 24px 70px rgba(8,22,35,.28); }
.confirmation-dialog__icon { display: grid; width: 46px; height: 46px; margin-bottom: 1rem; place-items: center; border-radius: 50%; color: #fffaf0; background: #8f2d24; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.7rem; font-weight: 900; }
.confirmation-dialog h2 { margin-top: .25rem; color: #10263d; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(1.7rem, 5vw, 2.4rem); line-height: 1; text-transform: uppercase; }
.confirmation-dialog > p:not(.eyebrow) { margin-top: .85rem; color: #53616b; line-height: 1.55; }
.confirmation-dialog > p strong { color: #10263d; }
.confirmation-dialog dl { display: grid; gap: .65rem; margin-top: 1rem; }
.confirmation-dialog dl div { padding: .75rem .85rem; border-radius: 12px; background: rgba(143,45,36,.055); }
.confirmation-dialog dt { color: #8f2d24; font-size: .65rem; font-weight: 900; letter-spacing: .07em; text-transform: uppercase; }
.confirmation-dialog dd { margin-top: .2rem; color: #263e52; font-size: .84rem; }
.confirmation-dialog .confirmation-dialog__note { font-size: .78rem; }
.confirmation-dialog__actions { display: flex; justify-content: flex-end; gap: .65rem; margin-top: 1.25rem; }
</style>

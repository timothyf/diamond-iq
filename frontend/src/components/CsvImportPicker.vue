<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue'

const props = defineProps({
  busy: {
    type: Boolean,
    default: false,
  },
  variant: {
    type: String,
    default: 'full',
  },
  statusMessage: {
    type: String,
    default: '',
  },
  uploadError: {
    type: String,
    default: '',
  },
})

const emit = defineEmits(['file-selected', 'import-request'])

const selectedFile = ref(null)
const validationMessage = ref('')
const fileInput = ref(null)
const progressValue = ref(0)
let progressTimer = null

const selectedFileSummary = computed(() => {
  if (!selectedFile.value) return 'No file selected yet.'

  const sizeInKb = Math.max(selectedFile.value.size / 1024, 0.1).toFixed(1)
  return `${selectedFile.value.name} · ${sizeInKb} KB`
})

const progressLabel = computed(() => {
  if (!props.busy) return ''

  return selectedFile.value
    ? `Importing ${selectedFile.value.name} into the Rails datastore…`
    : 'Importing CSV into the Rails datastore…'
})

function startProgressTimer() {
  stopProgressTimer()
  progressValue.value = 8

  progressTimer = window.setInterval(() => {
    if (progressValue.value >= 92) return

    const nextIncrement = progressValue.value < 40 ? 9 : progressValue.value < 70 ? 5 : 2
    progressValue.value = Math.min(progressValue.value + nextIncrement, 92)
  }, 220)
}

function stopProgressTimer() {
  if (progressTimer) {
    window.clearInterval(progressTimer)
    progressTimer = null
  }
}

function isCsvFile(file) {
  if (!file) return false

  const normalizedName = file.name.toLowerCase()
  return normalizedName.endsWith('.csv') || file.type === 'text/csv'
}

function clearSelection() {
  selectedFile.value = null
  validationMessage.value = ''

  if (fileInput.value) {
    fileInput.value.value = ''
  }
}

function handleFileSelection(event) {
  const [file] = event.target.files || []

  if (!file) {
    clearSelection()
    return
  }

  if (!isCsvFile(file)) {
    clearSelection()
    validationMessage.value = 'Please choose a file with a .csv extension.'
    return
  }

  selectedFile.value = file
  validationMessage.value = ''
  emit('file-selected', file)
}

function requestImport() {
  if (!selectedFile.value || validationMessage.value || props.busy) return

  emit('import-request', selectedFile.value)
}

watch(
  () => props.busy,
  (isBusy, wasBusy) => {
    if (isBusy) {
      startProgressTimer()
      return
    }

    stopProgressTimer()
    if (wasBusy) {
      progressValue.value = 100
    }
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  stopProgressTimer()
})
</script>

<template>
  <section :class="['import-station', { 'import-station--drawer': variant === 'drawer' }]">
    <div class="import-station__copy">
      <p class="eyebrow">CSV Intake</p>
      <h2>{{ variant === 'drawer' ? 'Player Season Stats Import' : 'Stage A Player Season Stats Import' }}</h2>
      <p>
        {{
          variant === 'drawer'
            ? 'Select a CSV export from your workstation to refresh the player season stats dataset.'
            : 'Select a CSV export from your workstation so we can hand it to the import flow once the upload endpoint is connected.'
        }}
      </p>
    </div>

    <div class="import-station__controls">
      <label class="import-dropzone" for="player-season-stats-csv">
        <input
          id="player-season-stats-csv"
          ref="fileInput"
          class="import-dropzone__input"
          type="file"
          accept=".csv,text/csv"
          @change="handleFileSelection"
        />

        <span class="import-dropzone__title">Choose CSV File</span>
        <span class="import-dropzone__detail">{{ selectedFileSummary }}</span>
      </label>

      <div class="import-station__actions">
        <button
          class="ghost-button"
          type="button"
          data-test="execute-import"
          :disabled="!selectedFile || busy"
          @click="requestImport"
        >
          {{ busy ? 'Importing…' : 'Import CSV' }}
        </button>
        <button
          class="ghost-button"
          type="button"
          data-test="clear-import-selection"
          :disabled="!selectedFile || busy"
          @click="clearSelection"
        >
          Clear Selection
        </button>
      </div>

      <div
        v-if="busy"
        class="import-progress"
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        <div class="import-progress__header">
          <strong>{{ progressLabel }}</strong>
          <span>{{ progressValue }}%</span>
        </div>
        <div
          class="import-progress__track"
          role="progressbar"
          aria-label="CSV import progress"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-valuenow="progressValue"
        >
          <span class="import-progress__fill" :style="{ width: `${progressValue}%` }" />
        </div>
        <p class="import-progress__note">
          Large historical files can take a little time while the API parses rows and upserts season stats.
        </p>
      </div>

      <p v-if="statusMessage" class="import-status">
        {{ statusMessage }}
      </p>

      <p v-if="validationMessage || uploadError" class="error-banner import-error">
        {{ validationMessage || uploadError }}
      </p>
    </div>
  </section>
</template>

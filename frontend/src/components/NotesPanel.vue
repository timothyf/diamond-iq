<script setup>
import { computed, onMounted, ref, toRef, watch } from 'vue'

import { useAuth } from '../composables/useAuth'
import { useNotes } from '../composables/useNotes'

const props = defineProps({
  targetType: { type: String, required: true },
  targetId: { type: [String, Number], required: true },
  title: { type: String, default: 'Notes' },
  lazy: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
})

const { user } = useAuth()
const canWrite = computed(() => Boolean(
  user.value && ['administrator', 'admin', 'analyst', 'coach', 'scout', 'editor'].includes(user.value.role),
))
const tagListId = computed(() => `note-tags-${props.targetType}-${String(props.targetId).replaceAll(/[^a-zA-Z0-9_-]/g, '-')}`)
const {
  notes, availableTags, loading, saving, error, load, create, update, remove, history, clear,
} = useNotes(toRef(props, 'targetType'), toRef(props, 'targetId'))
const opened = ref(!props.lazy)
const loaded = ref(false)
const body = ref('')
const noteDate = ref(today())
const tagText = ref('')
const editingId = ref(null)
const editBody = ref('')
const editDate = ref('')
const editTags = ref('')
const histories = ref({})

onMounted(() => {
  if (user.value && !props.lazy) loadOnce()
})

watch(
  () => [props.targetType, props.targetId],
  () => {
    loaded.value = false
    histories.value = {}
    clear()
    if (user.value && opened.value) loadOnce()
  },
)

watch(user, (currentUser) => {
  if (currentUser && opened.value) loadOnce()
  if (!currentUser) {
    loaded.value = false
    clear()
  }
})

async function loadOnce() {
  if (loaded.value || loading.value || !props.targetId) return
  await load()
  loaded.value = !error.value
}

function togglePanel(event) {
  opened.value = event.target.open
  if (opened.value && user.value) loadOnce()
}

async function submitNote() {
  const created = await create({
    body: body.value.trim(),
    noteDate: noteDate.value,
    tags: parseTags(tagText.value),
  })
  if (!created) return
  body.value = ''
  tagText.value = ''
  noteDate.value = today()
}

function beginEdit(note) {
  editingId.value = note.id
  editBody.value = note.body
  editDate.value = note.noteDate
  editTags.value = note.tags.map((tag) => tag.name).join(', ')
}

function cancelEdit() {
  editingId.value = null
}

async function saveEdit(note) {
  const updated = await update(note, {
    body: editBody.value.trim(),
    note_date: editDate.value,
    tags: parseTags(editTags.value),
  })
  if (updated) editingId.value = null
}

async function toggleHistory(note) {
  if (histories.value[note.id]) {
    const next = { ...histories.value }
    delete next[note.id]
    histories.value = next
    return
  }
  histories.value = { ...histories.value, [note.id]: await history(note) }
}

function parseTags(value) {
  return [...new Set(String(value || '').split(',').map((tag) => tag.trim().toLowerCase()).filter(Boolean))]
}

function today() {
  const now = new Date()
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 10)
}

function formatDate(value) {
  if (!value) return 'Undated'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    .format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return ''
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}
</script>

<template>
  <details
    v-if="user"
    class="notes-panel"
    :class="{ 'notes-panel--compact': compact }"
    :open="!lazy"
    data-test="notes-panel"
    @toggle="togglePanel"
  >
    <summary>
      <span><small>Staff intelligence</small><strong>{{ title }}</strong></span>
      <b>{{ loaded ? notes.length : '—' }}</b>
    </summary>

    <div class="notes-panel__body">
      <form v-if="canWrite" class="note-form" @submit.prevent="submitNote">
        <textarea v-model="body" required maxlength="20000" placeholder="Record an observation, decision, or follow-up…" />
        <div>
          <label>Date<input v-model="noteDate" required type="date" /></label>
          <label>Tags<input v-model="tagText" :list="tagListId" placeholder="mechanics, follow-up" /></label>
          <button type="submit" :disabled="saving || !body.trim()">{{ saving ? 'Saving…' : 'Add note' }}</button>
        </div>
        <datalist :id="tagListId">
          <option v-for="tag in availableTags" :key="tag.id" :value="tag.name" />
        </datalist>
      </form>
      <p v-else class="notes-panel__readonly">Your role has read-only access to staff notes.</p>

      <p v-if="error" class="notes-panel__error" role="alert">{{ error }}</p>
      <p v-if="loading">Loading notes…</p>

      <div v-else-if="notes.length" class="note-list">
        <article v-for="note in notes" :key="note.id">
          <form v-if="editingId === note.id" class="note-edit" @submit.prevent="saveEdit(note)">
            <textarea v-model="editBody" required maxlength="20000" />
            <div>
              <input v-model="editDate" required type="date" aria-label="Note date" />
              <input v-model="editTags" :list="tagListId" aria-label="Note tags" />
              <button type="submit" :disabled="saving">Save</button>
              <button type="button" @click="cancelEdit">Cancel</button>
            </div>
          </form>
          <template v-else>
            <header>
              <div><strong>{{ note.author?.name || 'Unknown user' }}</strong><time :datetime="note.noteDate">{{ formatDate(note.noteDate) }}</time></div>
              <small v-if="note.updatedAt !== note.createdAt">Edited by {{ note.lastEditedBy?.name }} · {{ formatTimestamp(note.updatedAt) }}</small>
            </header>
            <p>{{ note.body }}</p>
            <div class="note-tags">
              <span v-for="tag in note.tags" :key="tag.id" :style="{ '--tag-color': tag.color }">{{ tag.name }}</span>
            </div>
            <footer>
              <button type="button" @click="toggleHistory(note)">{{ histories[note.id] ? 'Hide' : 'History' }} ({{ note.historyCount }})</button>
              <template v-if="note.editable">
                <button type="button" @click="beginEdit(note)">Edit</button>
                <button type="button" class="danger" @click="remove(note)">Archive</button>
              </template>
            </footer>
          </template>
          <ol v-if="histories[note.id]" class="note-history">
            <li v-for="revision in histories[note.id]" :key="revision.id">
              <strong>v{{ revision.version }} · {{ revision.action }}</strong>
              <span>{{ revision.editor?.name }} · {{ formatTimestamp(revision.created_at) }}</span>
              <p>{{ revision.body }}</p>
            </li>
          </ol>
        </article>
      </div>
      <p v-else-if="loaded" class="notes-panel__empty">No notes have been recorded for this item.</p>
    </div>
  </details>
</template>

<style scoped>
.notes-panel { margin: 1rem 0; border: 1px solid rgba(23,54,82,.16); border-radius: 16px; color: #173652; background: rgba(255,252,244,.92); }
.notes-panel > summary { display: flex; justify-content: space-between; gap: 1rem; align-items: center; padding: .85rem 1rem; cursor: pointer; list-style: none; }
.notes-panel > summary span { display: grid; }.notes-panel > summary small { color: #9a6c35; font-size: .58rem; font-weight: 900; letter-spacing: .09em; text-transform: uppercase; }
.notes-panel > summary strong { font-size: .92rem; text-transform: uppercase; }.notes-panel > summary b { display: grid; min-width: 26px; height: 26px; place-items: center; border-radius: 50%; color: #fff; background: #20543c; font-size: .7rem; }
.notes-panel__body { padding: 0 1rem 1rem; }.note-form,.note-edit { display: grid; gap: .5rem; }
.note-form textarea,.note-edit textarea { min-height: 84px; resize: vertical; }.note-form > div,.note-edit > div { display: grid; grid-template-columns: 145px minmax(140px,1fr) auto; gap: .45rem; align-items: end; }
.note-form label { display: grid; gap: .2rem; color: #697784; font-size: .62rem; font-weight: 900; text-transform: uppercase; }
.notes-panel textarea,.notes-panel input,.notes-panel button { min-width: 0; padding: .52rem .62rem; border: 1px solid rgba(23,54,82,.18); border-radius: 8px; color: inherit; background: #fffdf8; font: inherit; }
.notes-panel button { cursor: pointer; font-size: .67rem; font-weight: 850; }.note-form button[type="submit"],.note-edit button[type="submit"] { border: 0; color: #fff; background: #20543c; }
.note-list { display: grid; gap: .6rem; margin-top: .8rem; }.note-list > article { padding: .75rem; border-radius: 12px; background: rgba(23,54,82,.055); }
.note-list header { display: flex; justify-content: space-between; gap: .5rem; }.note-list header div { display: flex; gap: .45rem; align-items: baseline; }.note-list time,.note-list header small { color: #72808a; font-size: .63rem; }
.note-list article > p { margin: .5rem 0; white-space: pre-wrap; font-size: .78rem; line-height: 1.5; }.note-tags { display: flex; flex-wrap: wrap; gap: .25rem; }
.note-tags span { padding: .18rem .42rem; border: 1px solid var(--tag-color); border-radius: 999px; color: var(--tag-color); background: #fff; font-size: .57rem; font-weight: 850; }
.note-list footer { display: flex; justify-content: flex-end; gap: .3rem; margin-top: .5rem; }.note-list footer button { padding: .3rem .5rem; background: transparent; }.note-list footer .danger { color: #922e25; }
.note-history { display: grid; gap: .4rem; margin: .6rem 0 0; padding: .6rem 0 0 1.3rem; border-top: 1px solid rgba(23,54,82,.1); }.note-history li { font-size: .65rem; }.note-history span { margin-left: .35rem; color: #71808c; }.note-history p { margin: .2rem 0; white-space: pre-wrap; }
.notes-panel__error { color: #922e25; font-size: .7rem; font-weight: 800; }.notes-panel__empty,.notes-panel__readonly,.notes-panel__body > p { color: #71808c; font-size: .7rem; }
.notes-panel--compact { margin: .5rem 0; }.notes-panel--compact > summary { padding: .6rem .75rem; }.notes-panel--compact .notes-panel__body { padding: 0 .75rem .75rem; }
@media (max-width: 680px) { .note-form > div,.note-edit > div { grid-template-columns: 1fr; }.note-list header { flex-direction: column; } }
</style>

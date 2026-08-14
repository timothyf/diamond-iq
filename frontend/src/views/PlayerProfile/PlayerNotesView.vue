<script setup>
import { inject } from 'vue'
import NotesPanel from '../../components/NotesPanel.vue'

const { player } = inject('player-profile-context')
</script>

<template>
  <section id="player-page-panel-notes" class="profile-page-content" data-test="player-page-panel-notes" role="tabpanel" aria-labelledby="player-page-player-notes">
    <header class="profile-section-heading">
      <div><p class="eyebrow">Staff intelligence</p><h2>Player Notes</h2></div>
    </header>
    <NotesPanel target-type="player" :target-id="player.id" title="Player notes" />
  </section>
</template>

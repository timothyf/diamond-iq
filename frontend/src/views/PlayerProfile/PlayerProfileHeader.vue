<script setup>
import AddToWatchlistControl from '../../components/AddToWatchlistControl.vue'

defineProps({
  player: { type: Object, required: true },
  initials: { type: String, required: true },
  headshotFailed: { type: Boolean, default: false },
  headerPositionLabel: { type: String, required: true },
  rosterLabel: { type: String, required: true },
  externalProfileLinks: { type: Array, default: () => [] },
  displayValue: { type: Function, required: true },
  formatDate: { type: Function, required: true },
})

const emit = defineEmits(['headshot-error', 'open-source'])
</script>

<template>
  <section class="profile-hero">
    <p class="profile-hero__title">Unified Player Profile - <span>MLB ID: {{ player.mlbId }}</span></p>

    <div
      class="profile-portrait"
      :class="{ 'profile-portrait--photo': player.profile?.headshotUrl && !headshotFailed }"
    >
      <img
        v-if="player.profile?.headshotUrl && !headshotFailed"
        :src="player.profile.headshotUrl"
        :alt="`${player.fullName} headshot`"
        @error="emit('headshot-error')"
      />
      <span v-else>{{ initials }}</span>
    </div>

    <div class="profile-identity">
      <h1>{{ player.fullName }}</h1>
      <div class="profile-summary-line">
        <p class="profile-teamline">
          <strong>
            <RouterLink
              v-if="player.displayTeam?.id || player.currentMembership?.team?.id || player.team?.id"
              :to="{ name: 'team-profile', params: { id: player.displayTeam?.id || player.currentMembership?.team?.id || player.team?.id } }"
            >
              {{ player.displayTeam?.name || player.currentMembership?.team?.name || player.team?.name }}
            </RouterLink>
            <template v-else>Team unavailable</template>
          </strong>
          <span>{{ headerPositionLabel }}</span>
        </p>
        <div class="profile-status" :class="{ 'profile-status--injured': player.currentMembership?.injured }">
          {{ rosterLabel }}
        </div>
      </div>
      <nav class="profile-primary-actions" aria-label="Player actions">
        <AddToWatchlistControl :player-id="player.id" :player-name="player.fullName" />
        <RouterLink
          class="compare-player-link"
          :to="{ name: 'player-comparison', query: { left: player.id } }"
          data-test="compare-player-link"
        >
          Compare player
          <span aria-hidden="true">⇄</span>
        </RouterLink>
      </nav>
    </div>

    <dl class="profile-bio">
      <div>
        <dt>Bats/Throws</dt>
        <dd>{{ displayValue(player.profile?.bats) }}/{{ displayValue(player.profile?.throws) }}</dd>
      </div>
      <div>
        <dt>Born</dt>
        <dd>{{ formatDate(player.profile?.birthDate) }}</dd>
      </div>
      <div>
        <dt>Size</dt>
        <dd>{{ displayValue(player.profile?.formattedHeight) }} - {{ displayValue(player.profile?.weightPounds) }} lb</dd>
      </div>
      <div>
        <dt>Age</dt>
        <dd>{{ displayValue(player.profile?.age) }}</dd>
      </div>
      <div>
        <dt>MLB debut</dt>
        <dd>{{ formatDate(player.profile?.mlbDebutDate) }}</dd>
      </div>
      <div class="profile-bio__empty" aria-hidden="true"></div>
    </dl>

    <div class="profile-hero__footer">
      <nav class="external-profile-links" aria-label="External player profiles">
        <a
          v-for="link in externalProfileLinks"
          :key="link.key"
          :href="link.href"
          target="_blank"
          rel="noopener noreferrer"
          :data-test="`external-profile-${link.key}`"
        >
          {{ link.label }}
          <span aria-hidden="true">↗</span>
        </a>
      </nav>

      <button
        type="button"
        class="profile-provenance-link"
        data-test="player-data-provenance-link"
        @click="emit('open-source', $event.currentTarget)"
      >
        Data sources & freshness
        <span aria-hidden="true">i</span>
      </button>
    </div>
  </section>
</template>


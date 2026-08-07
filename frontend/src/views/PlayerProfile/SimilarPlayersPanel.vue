<script setup>
import { inject } from 'vue'

const {
  player, titleize, similarityValue,
} = inject('player-profile-context')
</script>

<template>
  <section class="profile-panel similar-players-panel" data-test="similar-players">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Statistical neighbors</p>
        <h2>Similar players</h2>
      </div>
      <span v-if="player.similarPlayers.season">
        {{ player.similarPlayers.season }} {{ titleize(player.similarPlayers.category) }}
      </span>
    </header>

    <div v-if="player.similarPlayers.matches.length" class="similar-player-grid">
      <article
        v-for="match in player.similarPlayers.matches"
        :key="match.player.id"
        class="similar-player-card"
        :data-test="`similar-player-${match.player.id}`"
      >
        <div class="similar-player-card__heading">
          <img v-if="match.player.headshotUrl" :src="match.player.headshotUrl" :alt="`${match.player.fullName} headshot`" />
          <div>
            <RouterLink :to="{ name: 'player-profile', params: { id: match.player.id } }">
              {{ match.player.fullName }}
            </RouterLink>
            <span>
              {{ match.position?.abbreviation || '—' }}
              <template v-if="match.team?.abbreviation"> · {{ match.team.abbreviation }}</template>
            </span>
          </div>
          <strong>{{ match.similarityScore }}%</strong>
        </div>

        <dl>
          <div v-for="metric in match.closestMetrics" :key="metric.key">
            <dt>{{ metric.label }}</dt>
            <dd>
              {{ similarityValue(metric, metric.targetValue) }}
              <span aria-hidden="true">↔</span>
              {{ similarityValue(metric, metric.candidateValue) }}
            </dd>
          </div>
        </dl>

        <RouterLink
          class="similar-player-card__compare"
          :to="{ name: 'player-comparison', query: { left: player.id, right: match.player.id } }"
        >
          Compare side by side →
        </RouterLink>
      </article>
    </div>
    <p v-else class="profile-empty">
      Similar players will appear when at least three comparable same-season metrics are available.
    </p>
    <small v-if="player.similarPlayers.methodology" class="similar-player-methodology">
      {{ player.similarPlayers.methodology }}
    </small>
  </section>
</template>


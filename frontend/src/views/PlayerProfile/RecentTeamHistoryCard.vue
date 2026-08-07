<script setup>
import { inject } from 'vue'

const {
  player, formatDate, teamHistoryLabel,
} = inject('player-profile-context')
</script>

<template>
  <section class="profile-panel">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Organization trail</p>
        <h2>Team history</h2>
      </div>
      <span>{{ player.teamHistory.length }} {{ player.teamHistory.length === 1 ? 'organization tenure' : 'organization tenures' }}</span>
    </header>

    <ol v-if="player.teamHistory.length" class="team-timeline">
      <li v-for="membership in player.teamHistory" :key="membership.id">
        <span class="team-timeline__mark"></span>
        <div>
          <strong>
            <RouterLink v-if="membership.team?.id" :to="{ name: 'team-profile', params: { id: membership.team.id } }">
              {{ membership.team.name }}
            </RouterLink>
          </strong>
          <span>{{ formatDate(membership.startsOn) }} — {{ membership.endsOn ? formatDate(membership.endsOn) : 'Present' }}</span>
        </div>
        <small>{{ teamHistoryLabel(membership) }}</small>
      </li>
    </ol>
    <p v-else class="profile-empty">No dated team history has been synchronized.</p>
  </section>
</template>


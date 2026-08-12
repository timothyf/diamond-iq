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
        <h2>Player history</h2>
      </div>
      <span>{{ player.teamHistory.length }} {{ player.teamHistory.length === 1 ? 'organization tenure' : 'organization tenures' }}</span>
    </header>

    <dl class="organization-milestones" data-test="organization-milestones">
      <div>
        <dt>Draft information</dt>
        <dd v-if="player.profile?.draftYear">
          {{ player.profile.draftYear }} MLB Draft<template v-if="player.profile.draftTeam?.name"> · {{ player.profile.draftTeam.name }}</template>
        </dd>
        <dd v-else>Not available</dd>
      </div>
      <div>
        <dt>MLB debut</dt>
        <dd>{{ formatDate(player.profile?.mlbDebutDate) }}</dd>
      </div>
      <div class="organization-milestones__wide">
        <dt>Awards</dt>
        <dd v-if="player.profile?.awards?.length" class="organization-award-list">
          <span v-for="award in player.profile.awards" :key="`${award.id}-${award.season}-${award.date}`">
            {{ award.name }}<template v-if="award.season"> ({{ award.season }})</template>
          </span>
        </dd>
        <dd v-else>None recorded</dd>
      </div>
      <div class="organization-milestones__wide">
        <dt>All-Star selections</dt>
        <dd v-if="player.profile?.allStarSelections?.length">
          {{ player.profile.allStarSelections.join(', ') }} · {{ player.profile.allStarSelections.length }}× MLB All-Star
        </dd>
        <dd v-else>None recorded</dd>
      </div>
    </dl>

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

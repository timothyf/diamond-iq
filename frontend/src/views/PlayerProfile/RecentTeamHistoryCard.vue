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
          {{ player.profile.draftYear }} MLB Draft<template v-if="player.profile.draftRound"> · Round {{ player.profile.draftRound }}</template><template v-if="player.profile.draftRoundPickNumber">, Pick {{ player.profile.draftRoundPickNumber }}<template v-if="player.profile.draftPickNumber"> ({{ player.profile.draftPickNumber }})</template></template><template v-else-if="player.profile.draftPickNumber">, Pick {{ player.profile.draftPickNumber }}</template><template v-if="player.profile.draftTeam?.name"> · {{ player.profile.draftTeam.name }}</template>
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
    <section v-if="player.trades.length" class="trade-history" data-test="trade-history">
      <div class="trade-history__heading">
        <h3>Trades</h3>
        <span>{{ player.trades.length }} {{ player.trades.length === 1 ? 'trade' : 'trades' }}</span>
      </div>

      <article v-for="trade in player.trades" :key="trade.id" class="trade-history__card">
        <header>
          <strong>{{ formatDate(trade.occurredOn) }}</strong>
          <span>Trade</span>
        </header>
        <p>{{ trade.description }}</p>
        <ul>
          <li v-for="side in trade.sides" :key="side.team?.mlbId || side.team?.name">
            <strong>
              To
              <RouterLink v-if="side.team?.id" :to="{ name: 'team-profile', params: { id: side.team.id } }">
                {{ side.team.name }}
              </RouterLink>
              <template v-else>{{ side.team?.name || 'Unknown team' }}</template>
            </strong>
            <span>
              <template v-for="(tradePlayer, index) in side.players" :key="tradePlayer.mlbId">
                <template v-if="index"> · </template>
                <RouterLink v-if="tradePlayer.id" :to="{ name: 'player-profile', params: { id: tradePlayer.id } }">
                  {{ tradePlayer.fullName }}
                </RouterLink>
                <template v-else>{{ tradePlayer.fullName }}</template>
              </template>
            </span>
          </li>
        </ul>
      </article>
    </section>

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

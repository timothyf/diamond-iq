<script setup>
import { computed, ref, watch } from 'vue'

import { usePlayerProfile } from '../composables/usePlayerProfile'

const props = defineProps({
  playerId: {
    type: [String, Number],
    required: true,
  },
})

const playerId = computed(() => props.playerId)
const { player, loading, error, refresh } = usePlayerProfile(playerId)
const headshotFailed = ref(false)

watch(
  () => player.value?.profile?.headshotUrl,
  () => {
    headshotFailed.value = false
  },
)

const initials = computed(() =>
  [player.value?.firstName, player.value?.lastName]
    .filter(Boolean)
    .map((name) => name.charAt(0))
    .join(''),
)

const rosterLabel = computed(() => {
  const membership = player.value?.currentMembership
  if (!membership) return 'Roster status unavailable'
  return membership.sourceStatusDescription || titleize(membership.rosterStatus)
})

const positionLabel = computed(() => {
  const position = player.value?.positions?.primary
  return position ? `${position.abbreviation} · ${position.name}` : 'Position unavailable'
})

const careerRangeLabel = computed(() => {
  const career = player.value?.careerOverview
  if (!career?.firstSeason) return 'No seasons stored'

  const range = career.firstSeason === career.lastSeason
    ? String(career.firstSeason)
    : `${career.firstSeason}–${career.lastSeason}`
  const seasonLabel = career.seasonCount === 1 ? 'season' : 'seasons'
  return `${range} · ${career.seasonCount} ${seasonLabel}`
})

const pitchingMetrics = computed(() => [
  ['Pitches', player.value?.pitchIndicators.pitching.pitch_count],
  ['Games', player.value?.pitchIndicators.pitching.game_count],
  ['Avg velo', withUnit(player.value?.pitchIndicators.pitching.average_velocity, ' mph')],
  ['Max velo', withUnit(player.value?.pitchIndicators.pitching.max_velocity, ' mph')],
  ['Avg spin', withUnit(player.value?.pitchIndicators.pitching.average_spin_rate, ' rpm')],
  ['Strike rate', withUnit(player.value?.pitchIndicators.pitching.strike_percentage, '%')],
])

const battingMetrics = computed(() => [
  ['Pitches seen', player.value?.pitchIndicators.batting.pitches_seen],
  ['Games', player.value?.pitchIndicators.batting.game_count],
  ['Batted balls', player.value?.pitchIndicators.batting.batted_ball_count],
  ['Avg exit velo', withUnit(player.value?.pitchIndicators.batting.average_exit_velocity, ' mph')],
  ['Max exit velo', withUnit(player.value?.pitchIndicators.batting.max_exit_velocity, ' mph')],
  ['Hard-hit rate', withUnit(player.value?.pitchIndicators.batting.hard_hit_percentage, '%')],
])

function titleize(value) {
  return String(value || '')
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function withUnit(value, unit) {
  return value === null || value === undefined ? null : `${value}${unit}`
}

function displayValue(value) {
  return value === null || value === undefined || value === '' ? '—' : value
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(
    new Date(`${value}T12:00:00`),
  )
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value))
}
</script>

<template>
  <main class="profile-shell">
    <div v-if="loading" class="profile-state" data-test="profile-loading">
      <span class="loading-ball" aria-hidden="true"></span>
      <strong>Building player profile…</strong>
    </div>

    <div v-else-if="error" class="profile-state profile-state--error" data-test="profile-error">
      <p>{{ error }}</p>
      <button type="button" class="profile-button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="player">
      <RouterLink class="profile-back" to="/">← Back to stat board</RouterLink>

      <section class="profile-hero">
        <div
          class="profile-portrait"
          :class="{ 'profile-portrait--photo': player.profile?.headshotUrl && !headshotFailed }"
        >
          <img
            v-if="player.profile?.headshotUrl && !headshotFailed"
            :src="player.profile.headshotUrl"
            :alt="`${player.fullName} headshot`"
            @error="headshotFailed = true"
          />
          <span v-else>{{ initials }}</span>
        </div>

        <div class="profile-identity">
          <p class="eyebrow">Unified player profile · MLB {{ player.mlbId }}</p>
          <h1>{{ player.fullName }}</h1>
          <p class="profile-teamline">
            <strong>{{ player.currentMembership?.team?.name || player.team?.name || 'Team unavailable' }}</strong>
            <span>{{ positionLabel }}</span>
            <span v-if="player.currentMembership?.jerseyNumber">#{{ player.currentMembership.jerseyNumber }}</span>
          </p>
          <div class="profile-status" :class="{ 'profile-status--injured': player.currentMembership?.injured }">
            <span class="profile-status__dot"></span>
            {{ rosterLabel }}
          </div>
        </div>

        <dl class="profile-bio">
          <div>
            <dt>Bats / Throws</dt>
            <dd>{{ displayValue(player.profile?.bats) }} / {{ displayValue(player.profile?.throws) }}</dd>
          </div>
          <div>
            <dt>Size</dt>
            <dd>{{ displayValue(player.profile?.formattedHeight) }} · {{ displayValue(player.profile?.weightPounds) }} lb</dd>
          </div>
          <div>
            <dt>Born</dt>
            <dd>{{ formatDate(player.profile?.birthDate) }}<span v-if="player.profile?.age"> · Age {{ player.profile.age }}</span></dd>
          </div>
          <div>
            <dt>MLB debut</dt>
            <dd>{{ formatDate(player.profile?.mlbDebutDate) }}</dd>
          </div>
        </dl>
      </section>

      <section class="profile-panel profile-season">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Season snapshot</p>
            <h2>{{ player.seasonOverview.season || 'Current' }} {{ titleize(player.seasonOverview.category) }}</h2>
          </div>
          <span>{{ player.seasonOverview.stats.length }} available measures</span>
        </header>

        <div v-if="player.seasonOverview.stats.length" class="profile-stat-grid">
          <article v-for="stat in player.seasonOverview.stats" :key="stat.key" class="profile-stat">
            <span>{{ stat.label }}</span>
            <strong>{{ stat.value }}</strong>
            <small>{{ stat.scope_key }}</small>
          </article>
        </div>
        <p v-else class="profile-empty">No season overview has been imported for this player yet.</p>
      </section>

      <section class="profile-panel profile-career">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Career ledger</p>
            <h2>Career {{ titleize(player.careerOverview.category) }} Stats</h2>
          </div>
          <span>{{ careerRangeLabel }}</span>
        </header>

        <div v-if="player.careerOverview.stats.length" class="profile-stat-grid">
          <article v-for="stat in player.careerOverview.stats" :key="stat.key" class="profile-stat">
            <span>{{ stat.label }}</span>
            <strong>{{ stat.value }}</strong>
            <small>Career</small>
          </article>
        </div>
        <p v-else class="profile-empty">No career statistics have been imported for this player yet.</p>
      </section>

      <div class="profile-two-column">
        <section class="profile-panel">
          <header class="profile-section-heading">
            <div>
              <p class="eyebrow">Statcast pulse</p>
              <h2>Recent pitch indicators</h2>
            </div>
            <span>Latest {{ player.pitchIndicators.sampleSize }} per role</span>
          </header>

          <div class="indicator-groups">
            <article class="indicator-card" :class="{ 'indicator-card--primary': player.pitchIndicators.primaryRole === 'batter' }">
              <h3>As batter</h3>
              <dl>
                <div v-for="metric in battingMetrics" :key="metric[0]">
                  <dt>{{ metric[0] }}</dt>
                  <dd>{{ displayValue(metric[1]) }}</dd>
                </div>
              </dl>
            </article>
            <article class="indicator-card" :class="{ 'indicator-card--primary': player.pitchIndicators.primaryRole === 'pitcher' }">
              <h3>As pitcher</h3>
              <dl>
                <div v-for="metric in pitchingMetrics" :key="metric[0]">
                  <dt>{{ metric[0] }}</dt>
                  <dd>{{ displayValue(metric[1]) }}</dd>
                </div>
              </dl>
            </article>
          </div>
        </section>

        <section class="profile-panel">
          <header class="profile-section-heading">
            <div>
              <p class="eyebrow">Organization trail</p>
              <h2>Team history</h2>
            </div>
            <span>{{ player.teamHistory.length }} membership windows</span>
          </header>

          <ol v-if="player.teamHistory.length" class="team-timeline">
            <li v-for="membership in player.teamHistory" :key="membership.id">
              <span class="team-timeline__mark"></span>
              <div>
                <strong>{{ membership.team?.name }}</strong>
                <span>{{ formatDate(membership.startsOn) }} — {{ membership.endsOn ? formatDate(membership.endsOn) : 'Present' }}</span>
              </div>
              <small>{{ membership.sourceStatusDescription || titleize(membership.rosterStatus) }}</small>
            </li>
          </ol>
          <p v-else class="profile-empty">No dated team history has been synchronized.</p>
        </section>
      </div>

      <section class="profile-panel profile-sources">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Data provenance</p>
            <h2>Sources & freshness</h2>
          </div>
          <span>Profile updated {{ formatTimestamp(player.sourceMetadata.lastUpdatedAt) }}</span>
        </header>
        <div class="source-grid">
          <article v-for="dataset in player.sourceMetadata.datasets" :key="dataset.name">
            <strong>{{ titleize(dataset.name) }}</strong>
            <span>{{ dataset.sourceName || 'DiamondIQ' }}</span>
            <small>{{ formatTimestamp(dataset.lastUpdatedAt) }}</small>
          </article>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.profile-shell {
  min-height: calc(100vh - 74px);
  padding: 2.5rem 1.25rem 5rem;
  background:
    radial-gradient(circle at 12% 0%, rgba(151, 38, 31, 0.18), transparent 27%),
    radial-gradient(circle at 92% 10%, rgba(24, 77, 116, 0.2), transparent 28%),
    linear-gradient(180deg, #f7f1e3, #ead8b6);
}

.profile-shell > * {
  width: min(1420px, calc(100vw - 2.5rem));
  margin-inline: auto;
}

.profile-back {
  display: inline-flex;
  width: auto;
  margin-bottom: 1rem;
  color: #6d2a25;
  font-weight: 700;
  text-decoration: none;
}

.profile-hero,
.profile-panel {
  border: 1px solid rgba(16, 38, 61, 0.13);
  border-radius: 28px;
  background: rgba(255, 252, 244, 0.91);
  box-shadow: 0 20px 58px rgba(64, 43, 20, 0.11);
}

.profile-hero {
  display: grid;
  grid-template-columns: 170px minmax(0, 1.2fr) minmax(280px, 0.7fr);
  gap: 2rem;
  align-items: center;
  padding: 2rem;
}

.profile-portrait {
  position: relative;
  display: grid;
  place-items: center;
  overflow: hidden;
  aspect-ratio: 1;
  border: 5px solid rgba(255, 255, 255, 0.85);
  border-radius: 50%;
  color: #fff7e7;
  background: linear-gradient(145deg, #153a59, #8f2d24);
  box-shadow: 0 12px 28px rgba(16, 38, 61, 0.2);
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 3rem;
  font-weight: 800;
}

.profile-portrait img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
}

.profile-portrait--photo {
  background: #c9c9c9;
}

.profile-identity h1 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', 'DIN Condensed', sans-serif;
  font-size: clamp(2.8rem, 5vw, 5.8rem);
  line-height: 0.9;
  letter-spacing: -0.025em;
  text-transform: uppercase;
}

.profile-teamline {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem 0.8rem;
  margin-top: 1rem;
  color: #455563;
}

.profile-teamline span::before {
  margin-right: 0.8rem;
  color: #b79569;
  content: '•';
}

.profile-status {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.4rem 0.8rem;
  border-radius: 999px;
  color: #20543c;
  background: #e1f0e5;
  font-size: 0.84rem;
  font-weight: 800;
  text-transform: uppercase;
}

.profile-status--injured {
  color: #7d291f;
  background: #f5ddd5;
}

.profile-status__dot {
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 50%;
  background: currentColor;
}

.profile-bio {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  padding: 1.2rem;
  border-radius: 20px;
  background: rgba(16, 38, 61, 0.055);
}

.profile-bio dt,
.indicator-card dt {
  color: #71808c;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.profile-bio dd {
  color: #10263d;
  font-weight: 700;
}

.profile-panel {
  margin-top: 1.25rem;
  padding: 1.5rem;
}

.profile-section-heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
  margin-bottom: 1.3rem;
}

.profile-section-heading h2 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.7rem, 2.4vw, 2.5rem);
  line-height: 1;
  text-transform: uppercase;
}

.profile-section-heading > span {
  color: #697784;
  font-size: 0.85rem;
}

.profile-stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
  gap: 0.7rem;
}

.profile-stat {
  display: flex;
  flex-direction: column;
  min-height: 116px;
  padding: 0.9rem;
  border: 1px solid rgba(16, 38, 61, 0.08);
  border-radius: 16px;
  background: #fffdf7;
}

.profile-stat span,
.profile-stat small {
  color: #71808c;
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
}

.profile-stat strong {
  margin-block: auto;
  color: #8f2d24;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 2rem;
}

.profile-two-column {
  display: grid;
  grid-template-columns: 1.2fr 0.8fr;
  gap: 1.25rem;
}

.indicator-groups {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.85rem;
}

.indicator-card {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 18px;
  background: rgba(16, 38, 61, 0.035);
}

.indicator-card--primary {
  border-color: rgba(143, 45, 36, 0.28);
  background: rgba(143, 45, 36, 0.055);
}

.indicator-card h3 {
  margin-bottom: 0.75rem;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.25rem;
  text-transform: uppercase;
}

.indicator-card dl {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.indicator-card dd {
  color: #10263d;
  font-size: 1.1rem;
  font-weight: 800;
}

.team-timeline {
  display: grid;
  gap: 0;
  list-style: none;
}

.team-timeline li {
  position: relative;
  display: grid;
  grid-template-columns: 18px minmax(0, 1fr) auto;
  gap: 0.75rem;
  padding-bottom: 1.25rem;
}

.team-timeline li:not(:last-child)::before {
  position: absolute;
  top: 14px;
  bottom: 0;
  left: 6px;
  width: 2px;
  background: #d5c09e;
  content: '';
}

.team-timeline__mark {
  z-index: 1;
  width: 14px;
  height: 14px;
  margin-top: 5px;
  border: 3px solid #fffaf0;
  border-radius: 50%;
  background: #8f2d24;
  box-shadow: 0 0 0 1px #8f2d24;
}

.team-timeline div,
.team-timeline strong,
.team-timeline span {
  display: block;
}

.team-timeline span,
.team-timeline small {
  color: #697784;
  font-size: 0.8rem;
}

.source-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 0.75rem;
}

.source-grid article {
  display: flex;
  flex-direction: column;
  padding: 0.9rem;
  border-radius: 15px;
  background: rgba(16, 38, 61, 0.045);
}

.source-grid span,
.source-grid small {
  color: #697784;
}

.profile-state {
  display: grid;
  place-items: center;
  gap: 1rem;
  min-height: 50vh;
  text-align: center;
}

.loading-ball {
  width: 42px;
  height: 42px;
  border: 2px solid #8f2d24;
  border-radius: 50%;
  background: linear-gradient(90deg, transparent 48%, #8f2d24 49%, #8f2d24 51%, transparent 52%);
  animation: spin 900ms linear infinite;
}

.profile-button {
  padding: 0.7rem 1rem;
  border: 0;
  border-radius: 999px;
  color: white;
  background: #8f2d24;
  cursor: pointer;
}

.profile-empty {
  padding: 1.25rem;
  border-radius: 16px;
  color: #697784;
  background: rgba(16, 38, 61, 0.04);
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 980px) {
  .profile-hero {
    grid-template-columns: 130px 1fr;
  }

  .profile-bio {
    grid-column: 1 / -1;
  }

  .profile-two-column {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .profile-shell {
    padding-inline: 0.75rem;
  }

  .profile-shell > * {
    width: min(100%, calc(100vw - 1.5rem));
  }

  .profile-hero {
    grid-template-columns: 1fr;
    text-align: center;
  }

  .profile-portrait {
    width: 120px;
    margin-inline: auto;
  }

  .profile-teamline,
  .profile-status {
    justify-content: center;
  }

  .indicator-groups,
  .profile-bio {
    grid-template-columns: 1fr;
  }

  .profile-section-heading {
    flex-direction: column;
  }
}
</style>

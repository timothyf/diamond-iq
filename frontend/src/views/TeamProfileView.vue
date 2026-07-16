<script setup>
import { computed, ref, watch } from 'vue'

import { useTeamProfile } from '../composables/useTeamProfile'

const props = defineProps({
  teamId: { type: [String, Number], required: true },
})

const teamId = computed(() => props.teamId)
const selectedSeason = ref(null)
const selectedRosterView = ref('fortyMan')
const { team, loading, error, refresh } = useTeamProfile(teamId, selectedSeason)

watch(
  () => team.value?.season,
  (season) => {
    if (season && selectedSeason.value === null) selectedSeason.value = season
  },
)

watch(teamId, () => {
  selectedRosterView.value = 'fortyMan'
})

const displayedRoster = computed(() => team.value?.rosters?.[selectedRosterView.value] || [])

const rosterViewLabel = computed(() => (selectedRosterView.value === 'active' ? 'Active roster' : '40-man roster'))

const recordLabel = computed(() => {
  const record = team.value?.record
  if (!record?.games_played) return 'No completed games'
  return [record.wins, record.losses, ...(record.ties ? [record.ties] : [])].join('–')
})

const dashboard = computed(() => team.value?.performanceDashboard || {})

function formatDate(value, includeYear = false) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    ...(includeYear ? { year: 'numeric' } : {}),
  }).format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}

function titleize(value) {
  return String(value || 'Status unavailable').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function opponent(game) {
  return game.homeTeam.id === team.value.id ? game.awayTeam : game.homeTeam
}

function isHome(game) {
  return game.homeTeam.id === team.value.id
}

function teamScore(game) {
  return isHome(game) ? game.homeScore : game.awayScore
}

function opponentScore(game) {
  return isHome(game) ? game.awayScore : game.homeScore
}

function resultLabel(game) {
  if (teamScore(game) === null || teamScore(game) === undefined) return '—'
  if (teamScore(game) === opponentScore(game)) return 'T'
  return teamScore(game) > opponentScore(game) ? 'W' : 'L'
}

function probablePitcher(game) {
  return isHome(game) ? game.homeProbablePitcher : game.awayProbablePitcher
}

function formatDecimal(value, digits = 3) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return number.toFixed(digits)
}

function formatPercent(value, digits = 1) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return `${(number * 100).toFixed(digits)}%`
}

function formatRank(entry) {
  if (!entry || !entry.rank) return '—'
  return `#${entry.rank}`
}
</script>

<template>
  <main class="team-profile-shell">
    <div v-if="loading && !team" class="team-state" data-test="team-loading">Building team profile…</div>
    <div v-else-if="error" class="team-state team-state--error" data-test="team-error">
      <p>{{ error }}</p>
      <button type="button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="team">
      <RouterLink class="team-back" :to="{ name: 'teams' }">← All MLB teams</RouterLink>

      <section class="team-hero">
        <div class="team-logo"><img :src="team.logoUrl" :alt="`${team.name} logo`" /></div>
        <div class="team-identity">
          <p>Unified team profile · MLB {{ team.mlbId }}</p>
          <h1>{{ team.name }}</h1>
          <span>{{ team.abbreviation }} · {{ team.locationName }}</span>
        </div>
        <label class="season-picker">
          <span>Profile season</span>
          <select v-model.number="selectedSeason" data-test="team-season-select">
            <option v-for="season in team.availableSeasons" :key="season" :value="season">{{ season }}</option>
          </select>
        </label>
      </section>

      <section class="team-summary" aria-label="Season summary">
        <article><span>{{ team.season }} record</span><strong>{{ recordLabel }}</strong><small>{{ team.record.games_played || 0 }} games</small></article>
        <article><span>Run differential</span><strong>{{ (team.record.runs_scored || 0) - (team.record.runs_allowed || 0) }}</strong><small>{{ team.record.runs_scored || 0 }} RS · {{ team.record.runs_allowed || 0 }} RA</small></article>
        <article><span>Current roster</span><strong>{{ team.rosterSummary.total || 0 }}</strong><small>{{ team.rosterSummary.active || 0 }} active · {{ team.rosterSummary.injured || 0 }} injured</small></article>
        <article><span>Last updated</span><strong class="summary-date">{{ formatTimestamp(team.sourceMetadata.lastUpdatedAt) }}</strong><small>{{ team.sourceMetadata.sources.join(', ') || 'DiamondIQ' }}</small></article>
      </section>

      <section class="team-panel performance-panel" data-test="team-performance-dashboard">
        <header>
          <div><p>Daily analytics</p><h2>Team performance dashboard</h2></div>
          <span>Built from precomputed daily tables</span>
        </header>

        <div class="performance-grid">
          <article>
            <h3>Offensive rankings</h3>
            <dl>
              <div><dt>OPS</dt><dd>{{ formatRank(dashboard.rankings?.offense?.ops) }} · {{ formatDecimal(dashboard.rankings?.offense?.ops?.value) }}</dd></div>
              <div><dt>Runs / G</dt><dd>{{ formatRank(dashboard.rankings?.offense?.runs_per_game) }} · {{ formatDecimal(dashboard.rankings?.offense?.runs_per_game?.value) }}</dd></div>
              <div><dt>K Rate</dt><dd>{{ formatRank(dashboard.rankings?.offense?.strikeout_rate) }} · {{ formatPercent(dashboard.rankings?.offense?.strikeout_rate?.value) }}</dd></div>
              <div><dt>BB Rate</dt><dd>{{ formatRank(dashboard.rankings?.offense?.walk_rate) }} · {{ formatPercent(dashboard.rankings?.offense?.walk_rate?.value) }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>Pitching rankings</h3>
            <dl>
              <div><dt>ERA</dt><dd>{{ formatRank(dashboard.rankings?.pitching?.era) }} · {{ formatDecimal(dashboard.rankings?.pitching?.era?.value) }}</dd></div>
              <div><dt>WHIP</dt><dd>{{ formatRank(dashboard.rankings?.pitching?.whip) }} · {{ formatDecimal(dashboard.rankings?.pitching?.whip?.value) }}</dd></div>
              <div><dt>K Rate</dt><dd>{{ formatRank(dashboard.rankings?.pitching?.strikeout_rate) }} · {{ formatPercent(dashboard.rankings?.pitching?.strikeout_rate?.value) }}</dd></div>
              <div><dt>BB Rate</dt><dd>{{ formatRank(dashboard.rankings?.pitching?.walk_rate) }} · {{ formatPercent(dashboard.rankings?.pitching?.walk_rate?.value) }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>Recent form</h3>
            <dl>
              <div v-for="window in ['7', '15', '30']" :key="window">
                <dt>Last {{ window }} games</dt>
                <dd>
                  {{ dashboard.recentForm?.[window]?.wins || 0 }}-{{ dashboard.recentForm?.[window]?.losses || 0 }} ·
                  OPS {{ formatDecimal(dashboard.recentForm?.[window]?.ops) }} ·
                  ERA {{ formatDecimal(dashboard.recentForm?.[window]?.era) }}
                </dd>
              </div>
            </dl>
          </article>

          <article>
            <h3>Home / road</h3>
            <dl>
              <div><dt>Home</dt><dd>{{ dashboard.homeRoadSplits?.home?.wins || 0 }}-{{ dashboard.homeRoadSplits?.home?.losses || 0 }} · RD {{ dashboard.homeRoadSplits?.home?.run_differential || 0 }}</dd></div>
              <div><dt>Road</dt><dd>{{ dashboard.homeRoadSplits?.road?.wins || 0 }}-{{ dashboard.homeRoadSplits?.road?.losses || 0 }} · RD {{ dashboard.homeRoadSplits?.road?.run_differential || 0 }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>Platoon splits</h3>
            <dl>
              <div><dt>Offense vs LHP</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.offense?.vs_left?.strikeout_rate) }} · EV {{ formatDecimal(dashboard.platoonSplits?.offense?.vs_left?.average_exit_velocity, 1) }}</dd></div>
              <div><dt>Offense vs RHP</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.offense?.vs_right?.strikeout_rate) }} · EV {{ formatDecimal(dashboard.platoonSplits?.offense?.vs_right?.average_exit_velocity, 1) }}</dd></div>
              <div><dt>Pitching vs LHB</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.pitching?.vs_left?.strikeout_rate) }} · Velo {{ formatDecimal(dashboard.platoonSplits?.pitching?.vs_left?.average_velocity, 1) }}</dd></div>
              <div><dt>Pitching vs RHB</dt><dd>K {{ formatPercent(dashboard.platoonSplits?.pitching?.vs_right?.strikeout_rate) }} · Velo {{ formatDecimal(dashboard.platoonSplits?.pitching?.vs_right?.average_velocity, 1) }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>Starter / bullpen</h3>
            <dl>
              <div><dt>Starters</dt><dd>{{ formatDecimal(dashboard.starterBullpen?.starters?.innings_pitched, 1) }} IP · ERA {{ formatDecimal(dashboard.starterBullpen?.starters?.era) }} · WHIP {{ formatDecimal(dashboard.starterBullpen?.starters?.whip) }}</dd></div>
              <div><dt>Bullpen</dt><dd>{{ formatDecimal(dashboard.starterBullpen?.bullpen?.innings_pitched, 1) }} IP · ERA {{ formatDecimal(dashboard.starterBullpen?.bullpen?.era) }} · WHIP {{ formatDecimal(dashboard.starterBullpen?.bullpen?.whip) }}</dd></div>
            </dl>
          </article>

          <article>
            <h3>One-run games</h3>
            <dl>
              <div><dt>Record</dt><dd>{{ dashboard.oneRunPerformance?.wins || 0 }}-{{ dashboard.oneRunPerformance?.losses || 0 }}</dd></div>
              <div><dt>Win rate</dt><dd>{{ formatPercent(dashboard.oneRunPerformance?.winning_percentage) }}</dd></div>
              <div><dt>Games</dt><dd>{{ dashboard.oneRunPerformance?.games || 0 }}</dd></div>
            </dl>
          </article>
        </div>

        <div class="signals-grid">
          <article>
            <h3>Current strengths</h3>
            <ul>
              <li v-for="entry in dashboard.strengths || []" :key="entry">{{ entry }}</li>
            </ul>
          </article>
          <article>
            <h3>Areas of concern</h3>
            <ul>
              <li v-for="entry in dashboard.concerns || []" :key="entry">{{ entry }}</li>
            </ul>
          </article>
        </div>

        <div class="drilldown-grid">
          <article>
            <h3>Drill-down: games</h3>
            <ul>
              <li v-for="game in dashboard.drillDown?.games || []" :key="game.id">
                {{ formatDate(game.official_date, true) }} · {{ game.result }} · {{ game.score?.team }}-{{ game.score?.opponent }} vs {{ game.opponent }}
              </li>
            </ul>
          </article>
          <article>
            <h3>Drill-down: players</h3>
            <ul>
              <li v-for="playerEntry in dashboard.drillDown?.players?.hitters || []" :key="`h-${playerEntry.player?.id}`">
                <RouterLink v-if="playerEntry.player?.id" :to="{ name: 'player-profile', params: { id: playerEntry.player.id } }">
                  {{ playerEntry.player?.full_name }}
                </RouterLink>
                <template v-else>{{ playerEntry.player?.full_name || 'Unknown player' }}</template>
                · OPS {{ formatDecimal(playerEntry.ops) }}
              </li>
            </ul>
          </article>
          <article>
            <h3>Drill-down: plate appearances</h3>
            <p>Total tracked PA: {{ dashboard.drillDown?.plateAppearances?.teamTotal || 0 }}</p>
            <ul>
              <li v-for="entry in dashboard.drillDown?.plateAppearances?.leaders || []" :key="`pa-${entry.player?.id}`">
                {{ entry.player?.full_name }} · {{ entry.plate_appearances }} PA
              </li>
            </ul>
          </article>
          <article>
            <h3>Drill-down: pitches</h3>
            <p>Total tracked pitches: {{ dashboard.drillDown?.pitches?.teamTotal || 0 }}</p>
            <ul>
              <li v-for="entry in dashboard.drillDown?.pitches?.leaders || []" :key="`pi-${entry.player?.id}`">
                {{ entry.player?.full_name }} · {{ entry.pitches }} pitches
              </li>
            </ul>
          </article>
        </div>
      </section>

      <div class="team-schedule-grid">
        <section class="team-panel">
          <header><div><p>Next on the calendar</p><h2>Upcoming games</h2></div><span>{{ team.upcomingGames.length }} shown</span></header>
          <ol v-if="team.upcomingGames.length" class="game-list" data-test="upcoming-games">
            <li v-for="game in team.upcomingGames" :key="game.id">
              <time>{{ formatDate(game.officialDate) }}</time>
              <div><strong>{{ isHome(game) ? 'vs' : '@' }} {{ opponent(game).abbreviation }}</strong><span>{{ game.venueName || game.detailedStatus || 'Venue TBD' }}</span></div>
              <small>{{ probablePitcher(game)?.full_name || 'Probable TBD' }}</small>
            </li>
          </ol>
          <p v-else class="team-empty">No upcoming games are stored for this season.</p>
        </section>

        <section class="team-panel">
          <header><div><p>Latest finals</p><h2>Recent results</h2></div><span>{{ team.recentGames.length }} shown</span></header>
          <ol v-if="team.recentGames.length" class="game-list" data-test="recent-games">
            <li v-for="game in team.recentGames" :key="game.id">
              <time>{{ formatDate(game.officialDate) }}</time>
              <div><strong>{{ isHome(game) ? 'vs' : '@' }} {{ opponent(game).abbreviation }}</strong><span>{{ teamScore(game) }}–{{ opponentScore(game) }}</span></div>
              <b :class="`result result--${resultLabel(game).toLowerCase()}`">{{ resultLabel(game) }}</b>
            </li>
          </ol>
          <p v-else class="team-empty">No completed games are stored for this season.</p>
        </section>
      </div>

      <section class="team-panel roster-panel">
        <header>
          <div><p>Dated roster state</p><h2>Current roster</h2></div>
          <div class="roster-view-controls">
            <div role="group" aria-label="Roster view">
              <button
                type="button"
                data-test="roster-view-40man"
                :class="{ 'is-selected': selectedRosterView === 'fortyMan' }"
                :aria-pressed="selectedRosterView === 'fortyMan'"
                @click="selectedRosterView = 'fortyMan'"
              >
                40-man <span>{{ team.rosters.fortyMan.length }}</span>
              </button>
              <button
                type="button"
                data-test="roster-view-active"
                :class="{ 'is-selected': selectedRosterView === 'active' }"
                :aria-pressed="selectedRosterView === 'active'"
                @click="selectedRosterView = 'active'"
              >
                Active <span>{{ team.rosters.active.length }}</span>
              </button>
            </div>
            <small>As of {{ formatDate(team.rosterAsOf, true) }}</small>
          </div>
        </header>
        <div v-if="displayedRoster.length" class="roster-table-wrap" data-test="team-roster">
          <table>
            <thead><tr><th>Player</th><th>#</th><th>Pos</th><th>Status</th><th>Member since</th></tr></thead>
            <tbody>
              <tr v-for="membership in displayedRoster" :key="membership.id">
                <td>
                  <RouterLink class="roster-player" :to="{ name: 'player-profile', params: { id: membership.player.id } }">
                    <span class="roster-headshot">
                      <img v-if="membership.player.headshotUrl" :src="membership.player.headshotUrl" :alt="`${membership.player.fullName} headshot`" />
                      <b v-else>{{ membership.player.firstName?.[0] }}{{ membership.player.lastName?.[0] }}</b>
                    </span>
                    <strong>{{ membership.player.fullName }}</strong>
                  </RouterLink>
                </td>
                <td>{{ membership.jerseyNumber || '—' }}</td>
                <td>{{ membership.primaryPosition || '—' }}</td>
                <td><span class="roster-status" :class="{ 'roster-status--injured': membership.injured }">{{ membership.statusDescription || titleize(membership.rosterStatus) }}</span></td>
                <td>{{ formatDate(membership.startsOn, true) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="team-empty">No players are stored for this team's {{ rosterViewLabel.toLowerCase() }}.</p>
      </section>

      <footer class="team-freshness">
        <span>Schedule synced {{ formatTimestamp(team.sourceMetadata.scheduleLastSyncedAt) }}</span>
        <span>Roster synced {{ formatTimestamp(team.sourceMetadata.rosterLastSyncedAt) }}</span>
      </footer>
    </template>
  </main>
</template>

<style scoped>
.team-profile-shell { width: min(1500px, calc(100% - 2rem)); margin: 0 auto; padding: 2.2rem 0 5rem; color: #10263d; }
.team-back { color: #8d392e; font-size: .82rem; font-weight: 800; text-decoration: none; }
.team-hero { display: grid; grid-template-columns: 180px 1fr auto; gap: 2rem; align-items: center; margin-top: 1rem; padding: 2rem; border: 1px solid #d9d7ce; border-radius: 36px; background: rgba(255,250,240,.8); }
.team-logo { display: grid; place-items: center; width: 160px; height: 160px; border-radius: 50%; background: white; box-shadow: inset 0 0 0 1px #dedbd2; }
.team-logo img { width: 118px; height: 118px; object-fit: contain; }
.team-identity p, .team-panel header p { margin: 0; color: #a93627; font-size: .72rem; font-weight: 800; letter-spacing: .16em; text-transform: uppercase; }
.team-identity h1 { margin: .2rem 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(3.5rem, 7vw, 7rem); line-height: .9; text-transform: uppercase; }
.team-identity span { color: #53616c; font-size: 1.05rem; }
.season-picker span { display: block; margin-bottom: .35rem; color: #68737b; font-size: .72rem; font-weight: 800; text-transform: uppercase; }
.season-picker select { min-width: 120px; padding: .7rem .9rem; border: 1px solid #c9c8c0; border-radius: 12px; color: #10263d; background: white; font: inherit; font-weight: 800; }
.team-summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin: 1rem 0; }
.team-summary article, .team-panel { border: 1px solid #d9d7ce; border-radius: 24px; background: rgba(255,255,255,.72); }
.team-summary article { padding: 1.2rem; }
.team-summary span, .team-summary small, .team-summary strong { display: block; }
.team-summary span { color: #69747c; font-size: .7rem; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
.team-summary strong { margin: .25rem 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2.3rem; }
.team-summary .summary-date { font-family: inherit; font-size: .92rem; line-height: 2.6rem; }
.team-summary small { color: #788188; }
.team-schedule-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.team-panel { padding: 1.35rem; }
.performance-panel h3 { margin: 0 0 .55rem; font-size: .9rem; letter-spacing: .05em; text-transform: uppercase; color: #5f6c76; }
.performance-grid { display: grid; gap: .75rem; grid-template-columns: repeat(3, minmax(0, 1fr)); margin-top: 1rem; }
.performance-grid article, .signals-grid article, .drilldown-grid article { padding: .75rem; border: 1px solid #e3dfd7; border-radius: 14px; background: rgba(255,255,255,.66); }
.performance-grid dl { margin: 0; display: grid; gap: .35rem; }
.performance-grid dt { color: #6f7981; font-size: .72rem; font-weight: 700; }
.performance-grid dd { margin: 0; color: #1d3448; font-weight: 700; }
.signals-grid, .drilldown-grid { display: grid; gap: .75rem; margin-top: .85rem; grid-template-columns: repeat(2, minmax(0, 1fr)); }
.signals-grid ul, .drilldown-grid ul { margin: 0; padding-left: 1rem; color: #445767; }
.signals-grid li, .drilldown-grid li { margin: .22rem 0; }
.team-panel > header { display: flex; justify-content: space-between; align-items: end; gap: 1rem; padding-bottom: 1rem; border-bottom: 1px solid #e2e0d8; }
.team-panel h2 { margin: .12rem 0 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2rem; text-transform: uppercase; }
.team-panel header > span { color: #778087; font-size: .75rem; }
.game-list { margin: 0; padding: 0; list-style: none; }
.game-list li { display: grid; grid-template-columns: 82px 1fr auto; gap: .9rem; align-items: center; padding: .85rem 0; border-bottom: 1px solid #ece9e1; }
.game-list li:last-child { border-bottom: 0; }
.game-list time, .game-list small { color: #69747c; font-size: .76rem; }
.game-list strong, .game-list span { display: block; }
.game-list span { margin-top: .15rem; color: #758088; font-size: .75rem; }
.result { display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; color: white; font-size: .75rem; }
.result--w { background: #176044; } .result--l { background: #9c382c; } .result--t { background: #69747c; }
.roster-panel { margin-top: 1rem; }
.roster-view-controls { display: flex; gap: .8rem; align-items: center; }
.roster-view-controls > div { display: inline-flex; padding: .2rem; border-radius: 999px; background: #e9e6dd; }
.roster-view-controls button { display: inline-flex; gap: .35rem; align-items: center; padding: .42rem .7rem; border: 0; border-radius: 999px; color: #5c6871; background: transparent; font: inherit; font-size: .72rem; font-weight: 800; cursor: pointer; }
.roster-view-controls button span { display: grid; place-items: center; min-width: 20px; height: 20px; padding: 0 .3rem; border-radius: 999px; color: inherit; background: rgba(16,38,61,.09); font-size: .64rem; }
.roster-view-controls button.is-selected { color: #fffaf0; background: #10263d; box-shadow: 0 3px 10px rgba(16,38,61,.18); }
.roster-view-controls button.is-selected span { background: rgba(255,255,255,.16); }
.roster-view-controls > small { color: #778087; font-size: .7rem; white-space: nowrap; }
.roster-table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: .75rem .8rem; border-bottom: 1px solid #e8e5dd; text-align: left; }
th { color: #69747c; font-size: .68rem; letter-spacing: .08em; text-transform: uppercase; }
.roster-player { display: inline-flex; align-items: center; gap: .7rem; color: #10263d; text-decoration: none; }
.roster-player:hover strong { color: #a93627; }
.roster-headshot { display: grid; place-items: center; width: 42px; height: 42px; overflow: hidden; border-radius: 50%; color: white; background: #10263d; }
.roster-headshot img { width: 100%; height: 100%; object-fit: cover; object-position: center 16%; }
.roster-headshot b { font-size: .72rem; }
.roster-status { display: inline-block; padding: .3rem .55rem; border-radius: 999px; color: #176044; background: #dcefe5; font-size: .7rem; font-weight: 800; }
.roster-status--injured { color: #8d392e; background: #f3dfd8; }
.team-empty { padding: 1rem 0 0; color: #758088; }
.team-freshness { display: flex; justify-content: flex-end; gap: 1.5rem; padding: 1rem; color: #727c83; font-size: .72rem; }
.team-state { margin-top: 2rem; padding: 2rem; border-radius: 20px; background: #fffaf0; }
.team-state--error { color: #8f2e23; }
.team-state button { padding: .65rem 1rem; border: 0; border-radius: 999px; color: white; background: #10263d; font-weight: 800; }
@media (max-width: 900px) { .team-hero { grid-template-columns: 100px 1fr; } .team-logo { width: 90px; height: 90px; } .team-logo img { width: 68px; height: 68px; } .season-picker { grid-column: 1 / -1; } .team-summary { grid-template-columns: 1fr 1fr; } .team-schedule-grid { grid-template-columns: 1fr; } .performance-grid { grid-template-columns: 1fr 1fr; } .signals-grid, .drilldown-grid { grid-template-columns: 1fr; } .roster-panel > header { align-items: flex-start; flex-direction: column; } }
@media (max-width: 560px) { .team-hero { grid-template-columns: 1fr; padding: 1.25rem; } .team-summary { grid-template-columns: 1fr; } .team-identity h1 { font-size: 3.4rem; } .game-list li { grid-template-columns: 68px 1fr auto; } .roster-view-controls { width: 100%; align-items: flex-start; flex-direction: column; } }
</style>

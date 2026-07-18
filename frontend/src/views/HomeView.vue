<script setup>
import { computed } from 'vue'

import { useHomeDashboard } from '../composables/useHomeDashboard'

const { dashboard, loading, error, refresh } = useHomeDashboard()

const briefingDate = computed(() => formatDate(dashboard.value.as_of, { weekday: 'long', month: 'long', day: 'numeric' }))
const lastUpdatedAt = computed(() => {
  const values = Object.values(dashboard.value.freshness || {}).filter(Boolean)
  return values.sort().at(-1) || null
})

function formatDate(value, options = { month: 'short', day: 'numeric' }) {
  if (!value) return 'Today'
  const date = new Date(`${value}T12:00:00`)
  return new Intl.DateTimeFormat('en-US', options).format(date)
}

function formatTime(value) {
  if (!value) return 'Time TBD'
  return new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' }).format(new Date(value))
}

function formatTimestamp(value) {
  if (!value) return 'Not available'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(value))
}

function gameState(game) {
  const status = String(game.status || '').toLowerCase()
  if (game.home_score !== null && game.home_score !== undefined && ['final', 'completed'].some((value) => status.includes(value))) return 'Final'
  if (['live', 'in progress', 'manager challenge'].some((value) => status.includes(value))) return game.detailed_status || 'Live'
  return formatTime(game.scheduled_at)
}

function score(game, side) {
  const value = game[`${side}_score`]
  return value === null || value === undefined ? '—' : value
}

function leaderValue(leader, value) {
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  if (leader.key === 'ops') return number.toFixed(3)
  if (leader.key === 'ERA') return number.toFixed(2)
  return Math.round(number).toLocaleString()
}

function record(entry, recent = false) {
  return recent
    ? `${entry.recent_wins}-${entry.recent_losses}`
    : `${entry.wins}-${entry.losses}`
}

function signed(value) {
  const number = Number(value || 0)
  return `${number > 0 ? '+' : ''}${number}`
}
</script>

<template>
  <main class="home-shell">
    <section class="home-hero">
      <div class="home-hero__copy">
        <p class="home-eyebrow">{{ dashboard.season || new Date().getFullYear() }} MLB briefing · {{ briefingDate }}</p>
        <h1>Baseball intelligence, ready for first pitch.</h1>
        <p>
          Track today’s slate, scan the league’s top performers, and move directly into the player and team analysis behind the numbers.
        </p>
        <div class="home-actions">
          <RouterLink class="home-button" :to="{ name: 'stat-explorer' }">Explore league stats</RouterLink>
          <RouterLink class="home-button home-button--secondary" :to="{ name: 'teams' }">Browse all teams</RouterLink>
        </div>
      </div>
      <aside class="home-hero__signal" aria-label="DiamondIQ quick start">
        <span>Start with a name</span>
        <strong>Find any player from the search bar above.</strong>
        <small>Jump from season totals into career history, rolling trends, pitch-level analysis, and contextual benchmarks.</small>
      </aside>
    </section>

    <div v-if="loading" class="home-state" data-test="home-loading">
      <span aria-hidden="true"></span>
      Building today’s briefing…
    </div>
    <div v-else-if="error" class="home-state home-state--error" data-test="home-error">
      <p>{{ error }}</p>
      <button type="button" @click="refresh">Try again</button>
    </div>

    <template v-else>
      <section class="home-panel slate-panel" data-test="today-games">
        <header class="home-heading">
          <div><p class="home-eyebrow">Today’s slate</p><h2>Games around the league</h2></div>
          <span>{{ dashboard.games.length }} {{ dashboard.games.length === 1 ? 'game' : 'games' }}</span>
        </header>
        <div v-if="dashboard.games.length" class="game-grid">
          <article v-for="game in dashboard.games" :key="game.id" class="game-card">
            <RouterLink
              class="game-card__summary-link"
              :to="{ name: 'game-summary', params: { id: game.id } }"
              :aria-label="`View ${game.away_team.name} at ${game.home_team.name} game summary`"
              data-test="game-summary-link"
            ></RouterLink>
            <header><span>{{ gameState(game) }}</span><small>{{ game.venue_name || 'Venue TBD' }}</small></header>
            <RouterLink :to="{ name: 'team-profile', params: { id: game.away_team.id } }" class="game-team">
              <b>{{ game.away_team.abbreviation }}</b><strong>{{ game.away_team.name }}</strong><em>{{ score(game, 'away') }}</em>
            </RouterLink>
            <RouterLink :to="{ name: 'team-profile', params: { id: game.home_team.id } }" class="game-team">
              <b>{{ game.home_team.abbreviation }}</b><strong>{{ game.home_team.name }}</strong><em>{{ score(game, 'home') }}</em>
            </RouterLink>
            <footer>
              <span>{{ game.away_probable_pitcher?.full_name || 'Away probable TBD' }}</span>
              <span>{{ game.home_probable_pitcher?.full_name || 'Home probable TBD' }}</span>
            </footer>
          </article>
        </div>
        <p v-else class="home-empty">No games are stored for {{ briefingDate }}.</p>
      </section>

      <section class="home-panel" data-test="home-leaders">
        <header class="home-heading">
          <div><p class="home-eyebrow">At the top</p><h2>{{ dashboard.season }} league leaders</h2></div>
          <RouterLink :to="{ name: 'stat-explorer' }">Open Stat Explorer →</RouterLink>
        </header>
        <div class="leader-grid">
          <article v-for="leader in dashboard.leaders" :key="leader.key" class="leader-card">
            <header><h3>{{ leader.label }}</h3><small v-if="leader.qualifier">{{ leader.qualifier }}</small></header>
            <ol v-if="leader.entries.length">
              <li v-for="entry in leader.entries" :key="entry.player.id">
                <span>{{ entry.rank }}</span>
                <RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">
                  <strong>{{ entry.player.full_name }}</strong><small>{{ entry.team.abbreviation }}</small>
                </RouterLink>
                <b>{{ leaderValue(leader, entry.value) }}</b>
              </li>
            </ol>
            <p v-else>No qualified leaders available.</p>
          </article>
        </div>
      </section>

      <section class="home-panel" data-test="league-pulse">
        <header class="home-heading">
          <div><p class="home-eyebrow">League pulse</p><h2>Teams setting the pace</h2></div>
          <RouterLink :to="{ name: 'teams' }">View team directory →</RouterLink>
        </header>
        <div class="pulse-grid">
          <article>
            <h3>Best records</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.best_records" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><span>{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ record(entry) }}</strong>
              </li>
            </ol>
          </article>
          <article>
            <h3>Run differential</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.run_differential" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><span>{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ signed(entry.run_differential) }}</strong>
              </li>
            </ol>
          </article>
          <article>
            <h3>Last {{ dashboard.team_pulse.recent_form[0]?.recent_games || 10 }} games</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.recent_form" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><span>{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ record(entry, true) }}</strong>
              </li>
            </ol>
          </article>
        </div>
      </section>

      <section class="quick-grid" aria-label="Explore DiamondIQ">
        <RouterLink :to="{ name: 'stat-explorer' }"><span>01</span><strong>Stat Explorer</strong><small>Filter and compare batting, pitching, and Statcast data.</small></RouterLink>
        <RouterLink :to="{ name: 'teams' }"><span>02</span><strong>Team Profiles</strong><small>Review records, rankings, recent form, schedules, and rosters.</small></RouterLink>
        <div><span>03</span><strong>Player Profiles</strong><small>Use player search to open career rates, trends, and benchmarks.</small></div>
      </section>

      <footer class="home-freshness">
        <span>DiamondIQ data briefing</span>
        <small>Latest stored update {{ formatTimestamp(lastUpdatedAt) }}</small>
      </footer>
    </template>
  </main>
</template>

<style scoped>
.home-shell { width: min(1440px, calc(100% - 2.5rem)); margin: 0 auto; padding: 2.4rem 0 5rem; color: #10263d; }
.home-hero { position: relative; display: grid; grid-template-columns: minmax(0, 1.45fr) minmax(280px, .55fr); gap: 1.2rem; padding: clamp(1.5rem, 4vw, 3.5rem); overflow: hidden; border-radius: 30px; color: #fffaf0; background: linear-gradient(125deg, #10263d 0%, #183e5b 62%, #8f2d24 145%); box-shadow: 0 24px 70px rgba(16,38,61,.18); }
.home-hero::after { position: absolute; right: -90px; bottom: -165px; width: 390px; height: 390px; border: 45px solid rgba(255,250,240,.045); border-radius: 50%; content: ''; }
.home-hero__copy { position: relative; z-index: 1; }
.home-eyebrow { margin: 0; color: #a93627; font-size: .71rem; font-weight: 900; letter-spacing: .16em; text-transform: uppercase; }
.home-hero .home-eyebrow { color: #e8b276; }
.home-hero h1 { max-width: 900px; margin: .45rem 0 .85rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(3rem, 7vw, 6.4rem); line-height: .88; letter-spacing: -.025em; text-transform: uppercase; }
.home-hero__copy > p:not(.home-eyebrow) { max-width: 750px; color: #d8e1e7; font-size: clamp(.95rem, 2vw, 1.15rem); line-height: 1.6; }
.home-actions { display: flex; flex-wrap: wrap; gap: .7rem; margin-top: 1.4rem; }
.home-button { padding: .75rem 1rem; border-radius: 11px; color: #10263d; background: #fffaf0; font-weight: 900; text-decoration: none; }
.home-button--secondary { color: #fffaf0; border: 1px solid rgba(255,255,255,.28); background: rgba(255,255,255,.08); }
.home-hero__signal { position: relative; z-index: 1; align-self: end; padding: 1.25rem; border: 1px solid rgba(255,255,255,.16); border-radius: 20px; background: rgba(7,23,37,.38); backdrop-filter: blur(8px); }
.home-hero__signal span, .home-hero__signal strong, .home-hero__signal small { display: block; }
.home-hero__signal span { color: #e8b276; font-size: .68rem; font-weight: 900; letter-spacing: .13em; text-transform: uppercase; }
.home-hero__signal strong { margin: .45rem 0; font-size: 1.25rem; line-height: 1.2; }
.home-hero__signal small { color: #c5d0d8; line-height: 1.5; }
.home-state, .home-panel { margin-top: 1.25rem; border: 1px solid rgba(16,38,61,.1); border-radius: 25px; background: rgba(255,252,245,.86); box-shadow: 0 14px 38px rgba(73,52,24,.065); }
.home-state { display: flex; gap: .7rem; align-items: center; padding: 1.5rem; font-weight: 800; }
.home-state > span { width: 12px; height: 12px; border-radius: 50%; background: #a93627; animation: pulse .8s infinite alternate; }
.home-state--error { justify-content: space-between; color: #8f2d24; }
.home-state button { padding: .6rem .9rem; border: 0; border-radius: 10px; color: white; background: #10263d; font-weight: 800; }
.home-panel { padding: clamp(1.1rem, 3vw, 1.65rem); }
.home-heading { display: flex; justify-content: space-between; gap: 1rem; align-items: end; margin-bottom: 1rem; }
.home-heading h2 { margin-top: .2rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(1.8rem, 4vw, 2.7rem); line-height: 1; text-transform: uppercase; }
.home-heading > span, .home-heading > a { color: #62707a; font-size: .77rem; font-weight: 800; text-decoration: none; }
.home-heading > a:hover { color: #a93627; }
.game-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(275px, 1fr)); gap: .8rem; }
.game-card { position: relative; min-width: 0; padding: 1rem; border: 1px solid rgba(16,38,61,.11); border-radius: 18px; background: rgba(255,255,255,.72); transition: border-color .16s ease, transform .16s ease, box-shadow .16s ease; }
.game-card:hover,.game-card:focus-within { border-color: rgba(169,54,39,.35); transform: translateY(-2px); box-shadow: 0 10px 24px rgba(16,38,61,.09); }
.game-card__summary-link { position: absolute; z-index: 1; inset: 0; border-radius: inherit; }
.game-card > header { display: flex; justify-content: space-between; gap: .5rem; padding-bottom: .65rem; border-bottom: 1px solid rgba(16,38,61,.08); }
.game-card > header span { color: #a93627; font-size: .73rem; font-weight: 900; text-transform: uppercase; }
.game-card > header small { overflow: hidden; color: #78838b; text-overflow: ellipsis; white-space: nowrap; }
.game-team { position: relative; z-index: 2; display: grid; grid-template-columns: 42px minmax(0,1fr) auto; gap: .65rem; align-items: center; padding-top: .75rem; color: #10263d; text-decoration: none; }
.game-team b { display: grid; width: 38px; height: 38px; place-items: center; border-radius: 50%; color: white; background: #183e5b; font-size: .7rem; }
.game-team strong { overflow: hidden; font-size: .88rem; text-overflow: ellipsis; white-space: nowrap; }
.game-team em { font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.7rem; font-style: normal; font-weight: 900; }
.game-card > footer { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; margin-top: .75rem; padding-top: .65rem; border-top: 1px solid rgba(16,38,61,.08); color: #6c7881; font-size: .67rem; }
.game-card > footer span:last-child { text-align: right; }
.leader-grid { display: grid; grid-template-columns: repeat(4, minmax(0,1fr)); gap: .8rem; }
.leader-card { padding: 1rem; border-radius: 18px; background: #10263d; color: #fffaf0; }
.leader-card > header { display: flex; justify-content: space-between; gap: .4rem; align-items: baseline; }
.leader-card h3 { font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.35rem; text-transform: uppercase; }
.leader-card > header small { color: #9fb0bc; font-size: .61rem; text-transform: uppercase; }
.leader-card ol { margin: .75rem 0 0; padding: 0; list-style: none; }
.leader-card li { display: grid; grid-template-columns: 20px minmax(0,1fr) auto; gap: .55rem; align-items: center; padding: .65rem 0; border-top: 1px solid rgba(255,255,255,.11); }
.leader-card li > span { color: #e8b276; font-weight: 900; }
.leader-card li a { min-width: 0; color: inherit; text-decoration: none; }
.leader-card li a strong, .leader-card li a small { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.leader-card li a strong { font-size: .83rem; }
.leader-card li a small { margin-top: .15rem; color: #9fb0bc; font-size: .65rem; }
.leader-card li > b { color: #e8b276; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.25rem; }
.leader-card > p { margin-top: 1rem; color: #aab7c0; font-size: .78rem; }
.pulse-grid { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: .8rem; }
.pulse-grid > article { padding: 1rem; border: 1px solid rgba(16,38,61,.1); border-radius: 18px; background: rgba(255,255,255,.67); }
.pulse-grid h3 { margin-bottom: .5rem; color: #a93627; font-size: .75rem; letter-spacing: .1em; text-transform: uppercase; }
.pulse-grid ol { margin: 0; padding: 0; list-style: none; }
.pulse-grid li { display: flex; justify-content: space-between; gap: .7rem; align-items: center; padding: .62rem 0; border-top: 1px solid rgba(16,38,61,.08); }
.pulse-grid li a { display: flex; min-width: 0; gap: .55rem; align-items: center; overflow: hidden; color: #344c60; font-size: .8rem; font-weight: 700; text-decoration: none; text-overflow: ellipsis; white-space: nowrap; }
.pulse-grid li a span { display: inline-grid; flex: 0 0 auto; width: 34px; height: 25px; place-items: center; border-radius: 7px; color: #fff; background: #183e5b; font-size: .61rem; }
.pulse-grid li strong { white-space: nowrap; }
.quick-grid { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: .8rem; margin-top: 1.25rem; }
.quick-grid > * { display: grid; padding: 1.1rem; border: 1px solid rgba(16,38,61,.1); border-radius: 18px; color: #10263d; background: rgba(255,252,245,.75); text-decoration: none; }
.quick-grid span { color: #a93627; font-size: .67rem; font-weight: 900; }
.quick-grid strong { margin: .3rem 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.25rem; text-transform: uppercase; }
.quick-grid small { color: #68757e; line-height: 1.45; }
.home-empty { padding: 1rem; border-radius: 14px; color: #68757e; background: rgba(231,237,241,.65); }
.home-freshness { display: flex; justify-content: space-between; gap: 1rem; padding: 1rem .2rem 0; color: #697680; font-size: .7rem; }
.home-freshness span { font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
@keyframes pulse { to { opacity: .25; transform: scale(.8); } }
@media (max-width: 1050px) { .leader-grid { grid-template-columns: repeat(2,minmax(0,1fr)); } .home-hero { grid-template-columns: 1fr; } .home-hero__signal { max-width: 600px; } }
@media (max-width: 760px) { .home-shell { width: min(100% - 1.2rem, 1440px); padding-top: 1rem; } .home-hero { padding: 1.4rem; border-radius: 22px; } .home-heading { align-items: flex-start; flex-direction: column; } .pulse-grid, .quick-grid { grid-template-columns: 1fr; } }
@media (max-width: 520px) { .leader-grid { grid-template-columns: 1fr; } .home-actions { align-items: stretch; flex-direction: column; } .home-button { text-align: center; } .home-freshness { flex-direction: column; } }
</style>

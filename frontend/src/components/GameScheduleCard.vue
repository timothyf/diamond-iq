<script setup>
defineProps({
  game: { type: Object, required: true },
})

function formatTime(value) {
  if (!value) return 'Time TBD'
  return new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' }).format(new Date(value))
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
</script>

<template>
  <article class="schedule-game-card">
    <RouterLink
      class="schedule-game-card__summary-link"
      :to="{ name: 'game-summary', params: { id: game.id } }"
      :aria-label="`View ${game.away_team.name} at ${game.home_team.name} game summary`"
      data-test="game-summary-link"
    />
    <header>
      <span>{{ gameState(game) }}</span>
      <small>{{ game.venue_name || 'Venue TBD' }}</small>
    </header>
    <RouterLink :to="{ name: 'team-profile', params: { id: game.away_team.id } }" class="schedule-game-card__team">
      <b>{{ game.away_team.abbreviation }}</b>
      <strong>{{ game.away_team.name }}</strong>
      <em>{{ score(game, 'away') }}</em>
    </RouterLink>
    <RouterLink :to="{ name: 'team-profile', params: { id: game.home_team.id } }" class="schedule-game-card__team">
      <b>{{ game.home_team.abbreviation }}</b>
      <strong>{{ game.home_team.name }}</strong>
      <em>{{ score(game, 'home') }}</em>
    </RouterLink>
    <footer>
      <span>{{ game.away_probable_pitcher?.full_name || 'Away probable TBD' }}</span>
      <span>{{ game.home_probable_pitcher?.full_name || 'Home probable TBD' }}</span>
    </footer>
  </article>
</template>

<style scoped>
.schedule-game-card { position: relative; min-width: 0; padding: 1rem; border: 1px solid rgba(16,38,61,.11); border-radius: 18px; background: rgba(255,255,255,.72); transition: border-color .16s ease, transform .16s ease, box-shadow .16s ease; }
.schedule-game-card:hover,.schedule-game-card:focus-within { border-color: rgba(169,54,39,.35); transform: translateY(-2px); box-shadow: 0 10px 24px rgba(16,38,61,.09); }
.schedule-game-card__summary-link { position: absolute; z-index: 1; inset: 0; border-radius: inherit; }
.schedule-game-card > header { display: flex; justify-content: space-between; gap: .5rem; padding-bottom: .65rem; border-bottom: 1px solid rgba(16,38,61,.08); }
.schedule-game-card > header span { color: #a93627; font-size: .73rem; font-weight: 900; text-transform: uppercase; }
.schedule-game-card > header small { overflow: hidden; color: #78838b; text-overflow: ellipsis; white-space: nowrap; }
.schedule-game-card__team { position: relative; z-index: 2; display: grid; grid-template-columns: 42px minmax(0,1fr) auto; gap: .65rem; align-items: center; padding-top: .75rem; color: #10263d; text-decoration: none; }
.schedule-game-card__team b { display: grid; width: 38px; height: 38px; place-items: center; border-radius: 50%; color: white; background: #183e5b; font-size: .7rem; }
.schedule-game-card__team strong { overflow: hidden; font-size: .88rem; text-overflow: ellipsis; white-space: nowrap; }
.schedule-game-card__team em { font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.7rem; font-style: normal; font-weight: 900; }
.schedule-game-card > footer { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; margin-top: .75rem; padding-top: .65rem; border-top: 1px solid rgba(16,38,61,.08); color: #6c7881; font-size: .67rem; }
.schedule-game-card > footer span:last-child { text-align: right; }
</style>

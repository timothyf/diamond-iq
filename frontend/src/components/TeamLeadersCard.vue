<script setup>
defineProps({
  leaders: { type: Object, required: true },
  season: { type: Number, required: true },
})

function formatValue(entry) {
  if (entry.value === null || entry.value === undefined) return '—'
  const value = Number(entry.value)
  if (!Number.isFinite(value)) return '—'
  if (['avg', 'ops'].includes(entry.key)) return value.toFixed(3).replace(/^0/, '')
  if (['ERA', 'whip'].includes(entry.key)) return value.toFixed(2)
  return Math.round(value).toLocaleString()
}

function initials(player) {
  return `${player?.first_name?.[0] || ''}${player?.last_name?.[0] || ''}` || '—'
}
</script>

<template>
  <section class="team-leaders-card" data-test="team-leaders">
    <header>
      <div><p>Season standouts</p><h2>Team leaders</h2></div>
      <span>{{ season }} regular season</span>
    </header>
    <div class="team-leaders-card__groups">
      <article v-for="category in ['batting', 'pitching']" :key="category">
        <h3>{{ category }}</h3>
        <div class="team-leaders-card__grid">
          <div v-for="entry in leaders[category] || []" :key="entry.key" class="team-leader" :data-test="`team-leader-${entry.key}`">
            <span class="team-leader__metric">{{ entry.abbreviation }}</span>
            <template v-if="entry.player">
              <RouterLink class="team-leader__player" :to="{ name: 'player-profile', params: { id: entry.player.id } }">
                <span class="team-leader__headshot">
                  <img v-if="entry.player.headshot_url" :src="entry.player.headshot_url" :alt="`${entry.player.full_name} headshot`" />
                  <b v-else>{{ initials(entry.player) }}</b>
                </span>
                <span><strong>{{ entry.player.full_name }}</strong><small>{{ entry.label }}</small></span>
              </RouterLink>
              <b class="team-leader__value">{{ formatValue(entry) }}</b>
            </template>
            <div v-else class="team-leader__empty">No qualified leader</div>
          </div>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
.team-leaders-card { margin-bottom: 1rem; overflow: hidden; border: 1px solid #d9d7ce; border-radius: 24px; background: rgba(255,255,255,.76); }
.team-leaders-card > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; padding: 1.25rem 1.35rem; color: #fffaf0; background: linear-gradient(120deg, #10263d, #1d4d73); }
.team-leaders-card header p { margin: 0; color: #e8b276; font-size: .7rem; font-weight: 900; letter-spacing: .14em; text-transform: uppercase; }
.team-leaders-card header h2 { margin-top: .15rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2rem; line-height: 1; text-transform: uppercase; }
.team-leaders-card header > span { color: #c9d4dc; font-size: .72rem; font-weight: 800; }
.team-leaders-card__groups { display: grid; grid-template-columns: 1fr 1fr; }
.team-leaders-card__groups > article { min-width: 0; padding: 1.1rem 1.25rem 1.25rem; }
.team-leaders-card__groups > article + article { border-left: 1px solid #e2e0d8; }
.team-leaders-card h3 { margin-bottom: .65rem; color: #a93627; font-size: .72rem; letter-spacing: .13em; text-transform: uppercase; }
.team-leaders-card__grid { display: grid; gap: .45rem; }
.team-leader { display: grid; grid-template-columns: 42px minmax(0,1fr) auto; gap: .7rem; align-items: center; min-height: 58px; padding: .45rem .6rem; border-radius: 14px; background: rgba(231,237,241,.55); }
.team-leader__metric { display: grid; width: 38px; height: 38px; place-items: center; border-radius: 50%; color: #fffaf0; background: #a93627; font-size: .64rem; font-weight: 900; }
.team-leader__player { display: flex; min-width: 0; gap: .65rem; align-items: center; color: #10263d; text-decoration: none; }
.team-leader__headshot { display: grid; flex: 0 0 auto; width: 46px; height: 46px; overflow: hidden; place-items: center; border-radius: 50%; color: #fff; background: #10263d; }
.team-leader__headshot img { width: 100%; height: 100%; object-fit: cover; object-position: center 16%; }
.team-leader__headshot b { font-size: .7rem; }
.team-leader__player > span:last-child { min-width: 0; }
.team-leader__player strong,.team-leader__player small { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.team-leader__player strong { font-size: .82rem; }
.team-leader__player small { margin-top: .1rem; color: #71808a; font-size: .65rem; }
.team-leader__player:hover strong { color: #a93627; }
.team-leader__value { color: #10263d; font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.65rem; }
.team-leader__empty { grid-column: 2 / -1; color: #788188; font-size: .76rem; }
@media (max-width: 800px) { .team-leaders-card__groups { grid-template-columns: 1fr; } .team-leaders-card__groups > article + article { border-top: 1px solid #e2e0d8; border-left: 0; } }
@media (max-width: 520px) { .team-leaders-card > header { align-items: flex-start; flex-direction: column; } .team-leader { grid-template-columns: 38px minmax(0,1fr) auto; padding-inline: .4rem; } .team-leader__headshot { width: 40px; height: 40px; } }
</style>

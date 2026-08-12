<script setup>
import { inject, ref, watch } from 'vue'

const {
  player, titleize, similarityValue, reloadSection, sectionLoading,
} = inject('player-profile-context')

const selectedSeason = ref('')
const comparisonMode = ref('season')
const minAge = ref('')
const maxAge = ref('')
const positionMatch = ref('any')

watch(
  () => player.value?.similarPlayers?.controls,
  (controls) => {
    if (!controls) return
    selectedSeason.value = controls.selectedSeason || player.value?.similarPlayers?.season || ''
    comparisonMode.value = controls.mode || 'season'
    minAge.value = controls.minAge ?? ''
    maxAge.value = controls.maxAge ?? ''
    positionMatch.value = controls.positionMatch || 'any'
  },
  { immediate: true },
)

function formatWeight(value) {
  const number = Number(value)
  return Number.isFinite(number) ? `${(number * 100).toFixed(0)}%` : '—'
}

function applyControls() {
  return reloadSection('similar_players', {
    similar_season: selectedSeason.value,
    similar_mode: comparisonMode.value,
    similar_min_age: minAge.value,
    similar_max_age: maxAge.value,
    similar_position: positionMatch.value,
  })
}

function clearControls() {
  minAge.value = ''
  maxAge.value = ''
  positionMatch.value = 'any'
  return applyControls()
}
</script>

<template>
  <section class="profile-panel similar-players-panel" data-test="similar-players">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Statistical neighbors</p>
        <h2>Similar players</h2>
      </div>
      <span v-if="player.similarPlayers.season">
        {{ player.similarPlayers.mode === 'career' ? 'Career' : player.similarPlayers.season }} {{ titleize(player.similarPlayers.category) }}
      </span>
    </header>

    <form class="similar-player-controls" data-test="similar-player-controls" @submit.prevent="applyControls">
      <fieldset class="similar-player-controls__mode">
        <legend>Current-season versus career mode</legend>
        <label :class="{ 'is-selected': comparisonMode === 'season' }">
          <input
            v-model="comparisonMode"
            data-test="similar-mode-season"
            type="radio"
            value="season"
            @change="applyControls"
          />
          <span>
            <strong>Current season</strong>
            Compare players using the selected season only.
          </span>
        </label>
        <label :class="{ 'is-selected': comparisonMode === 'career' }">
          <input
            v-model="comparisonMode"
            data-test="similar-mode-career"
            type="radio"
            value="career"
            @change="applyControls"
          />
          <span>
            <strong>Career</strong>
            Compare full-career totals and playing-time-weighted rates.
          </span>
        </label>
      </fieldset>

      <fieldset>
        <legend>Age and season controls</legend>
        <label>
          <span>Season</span>
          <select v-model="selectedSeason" data-test="similar-season-control" :disabled="comparisonMode === 'career'">
            <option
              v-for="season in (player.similarPlayers.controls.availableSeasons.length ? player.similarPlayers.controls.availableSeasons : [player.similarPlayers.season])"
              :key="season"
              :value="season"
            >
              {{ season }}
            </option>
          </select>
        </label>
        <label>
          <span>Minimum age</span>
          <input v-model="minAge" data-test="similar-min-age-control" type="number" min="16" max="60" placeholder="Any" />
        </label>
        <label>
          <span>Maximum age</span>
          <input v-model="maxAge" data-test="similar-max-age-control" type="number" min="16" max="60" placeholder="Any" />
        </label>
      </fieldset>

      <fieldset>
        <legend>Position controls</legend>
        <label>
          <span>Candidate positions</span>
          <select v-model="positionMatch" data-test="similar-position-control">
            <option
              v-for="option in (player.similarPlayers.controls.positionOptions.length ? player.similarPlayers.controls.positionOptions : [
                { value: 'any', label: 'Any position' },
                { value: 'same_type', label: 'Same position group' },
                { value: 'same_position', label: 'Same primary position' },
              ])"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
      </fieldset>

      <div class="similar-player-controls__actions">
        <button type="submit" :disabled="sectionLoading('similar_players').value">
          {{ sectionLoading('similar_players').value ? 'Updating…' : 'Apply controls' }}
        </button>
        <button type="button" class="profile-button--quiet" @click="clearControls">Clear</button>
      </div>
    </form>

    <p
      v-if="sectionLoading('similar_players').value"
      class="similar-player-loading"
      role="status"
      aria-live="polite"
    >
      Recalculating {{ comparisonMode === 'career' ? 'career' : 'season' }} comparisons…
    </p>

    <div v-if="player.similarPlayers.modelMetrics.length" class="similar-model-explainer" data-test="similar-player-model-metrics">
      <div>
        <h3>Metrics used in the model</h3>
        <p>Weights show each metric’s intended share of the similarity score.</p>
      </div>
      <div class="similar-model-metrics">
        <div v-for="metric in player.similarPlayers.modelMetrics" :key="metric.key">
          <span>{{ metric.label }}</span>
          <strong>{{ formatWeight(metric.weight) }}</strong>
        </div>
      </div>
    </div>

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
              <template v-if="match.age"> · Age {{ match.age }}</template>
            </span>
          </div>
          <strong>{{ match.similarityScore }}%</strong>
        </div>

        <div class="similar-player-card__why">
          <h3>Why this player is similar</h3>
          <ul>
            <li v-for="reason in match.whySimilar" :key="reason">{{ reason }}</li>
          </ul>
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

        <details class="similar-player-card__metrics">
          <summary>All {{ match.metricsUsed.length }} metrics used</summary>
          <table>
            <thead>
              <tr>
                <th>Metric</th>
                <th>{{ player.lastName }}</th>
                <th>{{ match.player.fullName }}</th>
                <th>Weight</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="metric in match.metricsUsed" :key="metric.key">
                <th>{{ metric.label }}</th>
                <td>{{ similarityValue(metric, metric.targetValue) }}</td>
                <td>{{ similarityValue(metric, metric.candidateValue) }}</td>
                <td>{{ formatWeight(metric.normalizedWeight) }}</td>
              </tr>
            </tbody>
          </table>
        </details>

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

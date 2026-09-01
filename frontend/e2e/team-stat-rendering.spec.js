import { expect, test } from '@playwright/test'

const teamProfile = {
  id: 401,
  mlb_id: 116,
  name: 'Render Test Tigers',
  abbreviation: 'RTT',
  team_name: 'Tigers',
  location_name: 'Render Test',
  short_name: 'Test Tigers',
  logo_url: null,
  season: 2026,
  available_seasons: [2026],
  record: { games_played: 0, wins: 0, losses: 0, ties: 0, recent: {} },
  division_rank: null,
  roster: [],
  rosters: { active: [], forty_man: [] },
  roster_as_of: null,
  roster_summary: {},
  recent_games: [],
  upcoming_games: [],
  schedule_games: [],
  player_stats: {
    season: 2026,
    batting: {
      columns: [
        { key: 'gamesPlayed', label: 'G' },
        { key: 'avg', label: 'AVG' },
        { key: 'homeRuns', label: 'HR' },
      ],
      players: [
        {
          player: { id: 501, full_name: 'Alpha Batter', first_name: 'Alpha', last_name: 'Batter', headshot_url: null },
          stats: { gamesPlayed: '12.0', avg: '0.250', homeRuns: '10.0' },
        },
        {
          player: { id: 502, full_name: 'Bravo Batter', first_name: 'Bravo', last_name: 'Batter', headshot_url: null },
          stats: { gamesPlayed: '13.0', avg: '0.321', homeRuns: '8.0' },
        },
      ],
    },
    pitching: {
      columns: [
        { key: 'W', label: 'W' },
        { key: 'ERA', label: 'ERA' },
        { key: 'whip', label: 'WHIP' },
      ],
      players: [
        {
          player: { id: 503, full_name: 'Charlie Pitcher', first_name: 'Charlie', last_name: 'Pitcher', headshot_url: null },
          stats: { W: '12.0', ERA: '0.75', whip: '0.90' },
        },
      ],
    },
  },
  team_stats: {
    season: 2026,
    batting: {
      columns: [
        { key: 'gamesPlayed', label: 'G' },
        { key: 'homeRuns', label: 'HR' },
        { key: 'avg', label: 'AVG' },
      ],
      teams: [
        {
          team: { id: 401, mlb_id: 116, name: 'Render Test Tigers', abbreviation: 'RTT', league: 'AL' },
          stats: { gamesPlayed: '130.0', homeRuns: '180.0', avg: '0.250' },
        },
        {
          team: { id: 402, mlb_id: 112, name: 'Bravo Cubs', abbreviation: 'BCU', league: 'NL' },
          stats: { gamesPlayed: '131.0', homeRuns: '200.0', avg: '0.275' },
        },
      ],
    },
    pitching: { columns: [], teams: [] },
  },
  team_stats_summary: { season: 2026, batting: {}, pitching: {} },
  team_leaders: { batting: [], pitching: [] },
  source_metadata: { sources: [] },
  performance_dashboard: {},
}

async function firstRowPlayerName(table) {
  return table.locator('tbody tr').first().getByRole('link').textContent()
}

async function firstRowTeamName(table) {
  return table.locator('tbody tr').first().getByRole('rowheader').textContent()
}

test('renders and sorts player and team statistics', async ({ page }) => {
  await page.route('**/api/teams/e2e-stat-rendering**', async (route) => {
    await route.fulfill({
      contentType: 'application/json',
      body: JSON.stringify({ data: teamProfile }),
    })
  })

  await page.goto('/teams/e2e-stat-rendering?tab=player-stats')

  const playerStats = page.getByTestId('team-profile-panel-player-stats')
  const battingTable = playerStats.getByTestId('team-player-stats-batting')
  await expect(battingTable).toBeVisible()
  await expect(battingTable.locator('tbody tr').first()).toContainText('Alpha Batter')
  await expect(battingTable.locator('tbody tr').first()).toContainText('12')
  await expect(battingTable.locator('tbody tr').first()).toContainText('.250')
  await expect(battingTable.locator('tbody tr').first()).toContainText('10')

  await battingTable.getByRole('button', { name: 'AVG' }).click()
  await expect.poll(() => firstRowPlayerName(battingTable)).toContain('Bravo Batter')
  await expect(battingTable.getByRole('button', { name: 'AVG' })).toHaveAttribute('aria-sort', 'descending')

  await battingTable.getByRole('button', { name: 'AVG' }).click()
  await expect.poll(() => firstRowPlayerName(battingTable)).toContain('Alpha Batter')
  await expect(battingTable.getByRole('button', { name: 'AVG' })).toHaveAttribute('aria-sort', 'ascending')

  await playerStats.getByRole('button', { name: 'Pitching' }).click()
  const pitchingTable = playerStats.getByTestId('team-player-stats-pitching')
  await expect(pitchingTable.locator('tbody tr').first()).toContainText('Charlie Pitcher')
  await expect(pitchingTable.locator('tbody tr').first()).toContainText('12')
  await expect(pitchingTable.locator('tbody tr').first()).toContainText('0.75')
  await expect(pitchingTable.locator('tbody tr').first()).toContainText('0.90')

  await page.getByTestId('team-profile-tab-team-stats').click()
  const teamStats = page.getByTestId('team-stats-table')
  await expect(teamStats).toBeVisible()
  await expect(teamStats.locator('th.is-current-team')).toHaveText(/Render Test Tigers/)

  await teamStats.getByRole('button', { name: 'HR' }).click()
  await expect.poll(() => firstRowTeamName(teamStats)).toContain('Bravo Cubs')
  await expect(teamStats.locator('tbody tr').first()).toContainText('131')
  await expect(teamStats.locator('tbody tr').first()).toContainText('200')
  await expect(teamStats.locator('tbody tr').first()).toContainText('.275')

  await teamStats.getByRole('button', { name: 'HR' }).click()
  await expect.poll(() => firstRowTeamName(teamStats)).toContain('Render Test Tigers')
})

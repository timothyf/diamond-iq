import { computed, ref } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'

import AdminView from '../AdminView.vue'

const runTask = vi.fn()
const downloadStats = vi.fn()
const downloadPitchData = vi.fn()
const importStatsFile = vi.fn()
const importPitchFile = vi.fn()
const loadOverview = vi.fn()
const loadSnapshots = vi.fn()
const rosterSnapshots = ref([])

vi.mock('../../composables/useAdminTask', () => ({
  useAdminTask: () => ({
    runningTask: computed(() => ''),
    error: computed(() => ''),
    lastResult: ref(null),
    overviewLoading: computed(() => false),
    overviewError: computed(() => ''),
    scheduleImportRange: computed(() => ({
      earliestImportDate: '2026-03-26',
      latestImportDate: '2026-05-31',
    })),
    scheduleDateRange: computed(() => ({
      earliestGameDate: '2026-03-26',
      latestGameDate: '2026-09-22',
    })),
    mlbTeams: computed(() => [
      { id: 1, mlbId: 116, name: 'Detroit Tigers', abbreviation: 'DET', league: 'american' },
      { id: 2, mlbId: 119, name: 'Los Angeles Dodgers', abbreviation: 'LAD', league: 'national' },
    ]),
    databaseMetrics: computed(() => ({
      environment: 'development',
      adapter: 'PostgreSQL',
      databaseName: 'diamond_iq_development',
      serverVersion: '16.3',
      sizeBytes: 536870912,
      userTableSizeBytes: 402653184,
      tableCount: 20,
      estimatedRowCount: 4779000,
      estimatedDeadRowCount: 1250,
      measuredAt: '2026-07-15T22:00:00Z',
      largestTables: [
        {
          tableName: 'pitch_data',
          totalSizeBytes: 314572800,
          dataSizeBytes: 251658240,
          indexSizeBytes: 62914560,
          estimatedRowCount: 4649481,
          estimatedDeadRowCount: 1200,
          databasePercentage: 58.59,
        },
        {
          tableName: 'player_season_stats',
          totalSizeBytes: 67108864,
          dataSizeBytes: 41943040,
          indexSizeBytes: 25165824,
          estimatedRowCount: 125000,
          estimatedDeadRowCount: 50,
          databasePercentage: 12.5,
        },
      ],
    })),
    playerSeasonStatsMetrics: computed(() => ({
      earliestSeason: 1876,
      latestSeason: 2026,
      approximateRowCount: 4649481,
    })),
    pitchDataMetrics: computed(() => ({
      earliestGameDate: '2026-04-01',
      latestGameDate: '2026-05-31',
      approximateRowCount: 125000,
    })),
    gameDetailsMetrics: computed(() => ({
      synchronizedGameCount: 72,
      earliestGameDate: '2026-03-26',
      latestGameDate: '2026-05-31',
      battingLineCount: 2100,
      pitchingLineCount: 720,
      plateAppearanceCount: 5400,
      linkedPitchCount: 18000,
    })),
    loadOverview,
    runTask,
  }),
}))

vi.mock('../../composables/usePlayerSeasonStatsDownload', () => ({
  usePlayerSeasonStatsDownload: () => ({
    downloading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    downloadStats,
  }),
}))

vi.mock('../../composables/usePitchDataDownload', () => ({
  usePitchDataDownload: () => ({
    downloading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    downloadPitchData,
  }),
}))

vi.mock('../../composables/usePlayerSeasonStatsImport', () => ({
  usePlayerSeasonStatsImport: () => ({
    uploading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    importFile: importStatsFile,
  }),
}))

vi.mock('../../composables/usePitchDataImport', () => ({
  usePitchDataImport: () => ({
    uploading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    importFile: importPitchFile,
  }),
}))

vi.mock('../../composables/useRosterSnapshots', () => ({
  useRosterSnapshots: () => ({
    snapshots: computed(() => rosterSnapshots.value),
    loading: computed(() => false),
    error: computed(() => ''),
    loadSnapshots,
  }),
}))

describe('AdminView', () => {
  beforeEach(() => {
    runTask.mockReset().mockResolvedValue({ success: true })
    downloadStats.mockReset().mockResolvedValue({ success: true })
    downloadPitchData.mockReset().mockResolvedValue({ success: true })
    importStatsFile.mockReset().mockResolvedValue({ success: true })
    importPitchFile.mockReset().mockResolvedValue({ success: true })
    loadOverview.mockReset().mockResolvedValue({ success: true })
    loadSnapshots.mockReset().mockResolvedValue({ data: [] })
    rosterSnapshots.value = []
  })

  it('centralizes imports, downloads, and Rake-backed synchronization features', async () => {
    const wrapper = mount(AdminView)

    expect(wrapper.text()).toContain('Data administration')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('Development database')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('512 MB')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('PostgreSQL footprint')
    expect(wrapper.find('[data-test="database-details"]').exists()).toBe(false)
    await wrapper.get('[data-test="database-details-button"]').trigger('click')
    const databaseDetails = wrapper.get('[data-test="database-details"]')
    expect(databaseDetails.attributes('role')).toBe('dialog')
    expect(databaseDetails.attributes('aria-modal')).toBe('true')
    expect(databaseDetails.text()).toContain('diamond_iq_development')
    expect(databaseDetails.text()).toContain('PostgreSQL 16.3')
    expect(databaseDetails.text()).toContain('384 MB')
    expect(databaseDetails.text()).toContain('20')
    expect(databaseDetails.text()).toContain('4,779,000')
    expect(databaseDetails.text()).toContain('pitch_data')
    expect(databaseDetails.text()).toContain('300 MB')
    expect(databaseDetails.text()).toContain('60.0 MB')
    expect(databaseDetails.text()).toContain('58.59%')
    await wrapper.get('[data-test="database-details-close"]').trigger('click')
    expect(wrapper.find('[data-test="database-details"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('Player season statistics')
    expect(wrapper.text()).toContain('Statcast pitch data')
    expect(wrapper.get('[data-test="player-season-stats-coverage"]').text()).toContain('1876')
    expect(wrapper.get('[data-test="player-season-stats-coverage"]').text()).toContain('2026')
    expect(wrapper.get('[data-test="player-season-stats-coverage"]').text()).toContain('4,649,481 stat rows')
    expect(wrapper.get('[data-test="pitch-data-coverage"]').text()).toContain('Apr 1, 2026')
    expect(wrapper.get('[data-test="pitch-data-coverage"]').text()).toContain('May 31, 2026')
    expect(wrapper.get('[data-test="pitch-data-coverage"]').text()).toContain('125,000 pitch rows')
    expect(wrapper.get('[data-test="stats-download-form"]').text()).toContain('season-level batting or pitching statistics')
    expect(wrapper.get('[data-test="pitch-download-form"]').text()).toContain('pitch-by-pitch Statcast data')
    expect(wrapper.text()).toContain('Local file imports')
    expect(wrapper.text()).toContain('MLB schedule synchronization')
    expect(wrapper.get('[data-test="schedule-sync-form"]').text()).toContain('games, teams, venues, statuses, and probable pitchers')
    expect(wrapper.get('[data-test="game-details-sync-form"]').text()).toContain('player game lines, batting orders, substitutions, plate appearances')
    expect(wrapper.get('[data-test="game-details-coverage"]').text()).toContain('72')
    expect(wrapper.get('[data-test="game-details-coverage"]').text()).toContain('5,400 plate appearances')
    expect(wrapper.get('[data-test="game-details-coverage"]').text()).toContain('18,000 linked pitches')
    expect(wrapper.text()).toContain('MLB profile synchronization')
    expect(wrapper.get('[data-test="profile-sync-form"]').text()).toContain('biographical, handedness, position, and headshot information')
    expect(wrapper.text()).toContain('MLB 40-man roster synchronization')
    expect(wrapper.get('[data-test="roster-sync-form"]').text()).toContain('player profiles, roster status, and dated team memberships')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('All MLB teams')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('American League')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('National League')
    expect(wrapper.get('[data-test="roster-team"]').text()).toContain('DET · Detroit Tigers (AL)')
    expect(wrapper.text()).not.toContain('As of')
    expect(wrapper.text()).not.toContain('Roster type')
    expect(wrapper.text()).not.toContain('Full season')
    expect(wrapper.get('[data-test="roster-coverage-policy"]').text()).toContain('Completed seasons')
    expect(wrapper.get('[data-test="roster-coverage-policy"]').text()).toContain("40-man roster only")
    expect(wrapper.get('[data-test="roster-coverage-policy"]').text()).toContain('transaction-based workflow')
    expect(wrapper.get('[data-test="roster-snapshot-workspace"]').text()).toContain('Active and 40-man roster snapshots')
    expect(wrapper.get('[data-test="roster-snapshot-workspace"]').text()).toContain('without changing historical team memberships')
    expect(wrapper.text()).toContain('Rebuild current player positions')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('Imported schedule coverage')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('May 31, 2026')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('Stored game-date span')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('Sep 22, 2026')
  })

  it('submits download and synchronization forms through their existing services', async () => {
    const wrapper = mount(AdminView)

    await wrapper.get('[data-test="stats-download-form"]').trigger('submit')
    expect(downloadStats).toHaveBeenCalledWith(
      expect.objectContaining({ category: 'batting', replaceSeason: true }),
    )

    await wrapper.get('[data-test="schedule-sync-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_schedule_sync',
      expect.objectContaining({ game_types: 'R', sport_id: 1 }),
    )
    expect(loadOverview).toHaveBeenCalledTimes(3)

    await wrapper.get('[data-test="game-details-sync-form"]').trigger('submit')
    expect(wrapper.get('[data-test="game-details-confirmation"]').attributes('role')).toBe('dialog')
    expect(runTask).not.toHaveBeenCalledWith('mlb_game_details_sync', expect.anything())
    await wrapper.get('[data-test="game-details-continue"]').trigger('click')
    await flushPromises()
    expect(runTask).toHaveBeenCalledWith(
      'mlb_game_details_sync',
      expect.objectContaining({ start_date: expect.any(String), end_date: expect.any(String), mlb_game_id: null }),
    )
    expect(loadOverview).toHaveBeenCalledTimes(4)

    await wrapper.get('[data-test="profile-sync-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_player_profiles_sync',
      expect.objectContaining({ only_missing: true, batch_size: 50 }),
    )

    await wrapper.get('[data-test="roster-team-scope"]').setValue('national')
    await wrapper.get('[data-test="roster-sync-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_roster_sync',
      expect.objectContaining({ team_scope: 'national', team_mlb_id: null }),
    )
    expect(runTask.mock.calls.at(-1)[1]).not.toHaveProperty('as_of')
    expect(runTask.mock.calls.at(-1)[1]).not.toHaveProperty('roster_type')

    await wrapper.get('[data-test="snapshot-team"]').setValue('116')
    await wrapper.get('[data-test="roster-snapshot-form"]').trigger('submit')
    await flushPromises()
    expect(runTask).toHaveBeenLastCalledWith(
      'mlb_roster_snapshots_sync',
      expect.objectContaining({ team_mlb_id: '116', snapshot_on: expect.any(String) }),
    )
    expect(loadSnapshots).toHaveBeenCalledWith(
      expect.objectContaining({ teamMlbId: '116', on: expect.any(String) }),
    )
  })

  it('warns with a date-span estimate and allows cancellation before synchronizing game details', async () => {
    const wrapper = mount(AdminView)
    const form = wrapper.get('[data-test="game-details-sync-form"]')
    const dateInputs = form.findAll('input[type="date"]')
    await dateInputs[0].setValue('2026-07-01')
    await dateInputs[1].setValue('2026-07-07')

    await form.trigger('submit')

    const confirmation = wrapper.get('[data-test="game-details-confirmation"]')
    expect(confirmation.attributes('aria-modal')).toBe('true')
    expect(confirmation.text()).toContain('7 calendar days')
    expect(confirmation.text()).toContain('Jul 1, 2026–Jul 7, 2026')
    expect(confirmation.text()).toContain('about 6–11 minutes')
    expect(confirmation.text()).toContain('up to approximately 105 games')
    expect(confirmation.text()).toContain('Keep the Rails server running')
    expect(runTask).not.toHaveBeenCalled()

    await wrapper.get('[data-test="game-details-cancel"]').trigger('click')
    expect(wrapper.find('[data-test="game-details-confirmation"]').exists()).toBe(false)
    expect(runTask).not.toHaveBeenCalled()

    await form.trigger('submit')
    await wrapper.get('[data-test="game-details-continue"]').trigger('click')
    await flushPromises()
    expect(runTask).toHaveBeenCalledWith(
      'mlb_game_details_sync',
      { start_date: '2026-07-01', end_date: '2026-07-07', mlb_game_id: null },
    )
  })

  it('displays stored Active and 40-man snapshot players', async () => {
    rosterSnapshots.value = [
      {
        id: 1,
        roster_type: 'active',
        snapshot_on: '2026-07-15',
        source_name: 'MLB Stats API',
        last_synced_at: '2026-07-15T12:00:00Z',
        players: [{ mlb_id: 592450, player_id: 9, full_name: 'Aaron Judge', jersey_number: '99', position_code: 'RF', status_description: 'Active' }],
      },
      {
        id: 2,
        roster_type: '40Man',
        snapshot_on: '2026-07-15',
        source_name: 'MLB Stats API',
        last_synced_at: '2026-07-15T12:00:00Z',
        players: [{ mlb_id: 605280, player_id: null, full_name: 'Test Pitcher', jersey_number: '50', position_code: 'P', status_description: 'Minors' }],
      },
    ]

    const wrapper = mount(AdminView)
    await wrapper.vm.$nextTick()

    const workspace = wrapper.get('[data-test="roster-snapshot-workspace"]')
    expect(workspace.text()).toContain('Active roster')
    expect(workspace.text()).toContain('40-man roster')
    expect(workspace.text()).toContain('Aaron Judge')
    expect(workspace.text()).toContain('Test Pitcher')
  })
})

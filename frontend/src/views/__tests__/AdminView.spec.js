import { computed, ref } from 'vue'
import { mount } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'

import AdminView from '../AdminView.vue'

const runTask = vi.fn()
const downloadStats = vi.fn()
const downloadPitchData = vi.fn()
const importStatsFile = vi.fn()
const importPitchFile = vi.fn()
const loadOverview = vi.fn()

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
      sizeBytes: 536870912,
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

describe('AdminView', () => {
  beforeEach(() => {
    runTask.mockReset().mockResolvedValue({ success: true })
    downloadStats.mockReset().mockResolvedValue({ success: true })
    downloadPitchData.mockReset().mockResolvedValue({ success: true })
    importStatsFile.mockReset().mockResolvedValue({ success: true })
    importPitchFile.mockReset().mockResolvedValue({ success: true })
    loadOverview.mockReset().mockResolvedValue({ success: true })
  })

  it('centralizes imports, downloads, and Rake-backed synchronization features', () => {
    const wrapper = mount(AdminView)

    expect(wrapper.text()).toContain('Data administration')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('Development database')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('512 MB')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('PostgreSQL footprint')
    expect(wrapper.text()).toContain('Player season statistics')
    expect(wrapper.text()).toContain('Statcast pitch data')
    expect(wrapper.text()).toContain('Local file imports')
    expect(wrapper.text()).toContain('MLB schedule synchronization')
    expect(wrapper.text()).toContain('MLB profile synchronization')
    expect(wrapper.text()).toContain('MLB team roster synchronization')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('All MLB teams')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('American League')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('National League')
    expect(wrapper.get('[data-test="roster-team"]').text()).toContain('DET · Detroit Tigers (AL)')
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
    expect(loadOverview).toHaveBeenCalledTimes(2)

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
  })
})

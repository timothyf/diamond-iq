import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, h } from 'vue'
import { afterEach, beforeEach, vi } from 'vitest'

import { useRosterSync } from '../useRosterSync'

function taskPayload(overrides = {}) {
  return {
    id: 13,
    task_name: 'mlb_roster_sync',
    status: 'running',
    task_parameters: { team_scope: 'national', team_mlb_id: null, season: 2026 },
    total_items: 15,
    completed_items: 6,
    failed_items: 1,
    processed_items: 7,
    progress_percentage: 46.7,
    current_item_mlb_id: 116,
    current_item_label: 'DET · Detroit Tigers',
    cancel_requested: false,
    elapsed_seconds: 56,
    estimated_remaining_seconds: 64,
    ...overrides,
  }
}

function mountComposable() {
  let api
  const wrapper = mount(defineComponent({
    setup() {
      api = useRosterSync()
      return () => h('div')
    },
  }))
  return { api, wrapper }
}

describe('useRosterSync', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('loads the estimate and starts a tracked roster task', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: {
            task_parameters: { team_scope: 'national', team_mlb_id: null, season: 2026 },
            team_count: 15,
            estimated_seconds: 120,
            low_estimated_seconds: 90,
            high_estimated_seconds: 180,
            seconds_per_team: 8,
            timing_sample_team_count: 0,
            timing_sample_run_count: 0,
            estimate_source: 'conservative_default',
          },
        }),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ data: taskPayload({ status: 'queued', completed_items: 0, failed_items: 0, processed_items: 0, progress_percentage: 0 }) }),
      })
    vi.stubGlobal('fetch', fetchMock)
    const { api, wrapper } = mountComposable()
    const parameters = { team_scope: 'national', team_mlb_id: null, season: 2026 }

    const estimate = await api.estimate(parameters)
    expect(estimate).toMatchObject({ teamCount: 15, estimatedSeconds: 120, secondsPerTeam: 8 })
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/admin/task_runs/estimate?task_name=mlb_roster_sync&team_scope=national&season=2026',
      expect.any(Object),
    )

    await api.start(parameters)
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/admin/task_runs',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ task_name: 'mlb_roster_sync', ...parameters }),
      }),
    )
    expect(api.active.value).toBe(true)
    wrapper.unmount()
  })

  it('recovers, polls, and safely cancels a running roster task', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: [taskPayload()] }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: taskPayload({ completed_items: 7, processed_items: 8, progress_percentage: 53.3 }) }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: taskPayload({ completed_items: 7, processed_items: 8, progress_percentage: 53.3, cancel_requested: true }) }) })
    vi.stubGlobal('fetch', fetchMock)
    const { api, wrapper } = mountComposable()

    await api.loadActiveTask()
    expect(api.task.value).toMatchObject({ totalItems: 15, processedItems: 7, currentItemLabel: 'DET · Detroit Tigers' })

    await vi.advanceTimersByTimeAsync(1500)
    await flushPromises()
    expect(api.task.value.processedItems).toBe(8)

    await api.cancel()
    expect(fetchMock).toHaveBeenNthCalledWith(3, '/api/admin/task_runs/13/cancel', expect.objectContaining({ method: 'POST' }))
    expect(api.task.value.cancelRequested).toBe(true)
    wrapper.unmount()
  })
})

import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, h } from 'vue'
import { afterEach, beforeEach, vi } from 'vitest'

import { useGameDetailsSync } from '../useGameDetailsSync'

function taskPayload(overrides = {}) {
  return {
    id: 11,
    task_name: 'mlb_game_details_sync',
    status: 'running',
    task_parameters: { start_date: '2026-07-01', end_date: '2026-07-07' },
    total_items: 105,
    completed_items: 45,
    failed_items: 2,
    processed_items: 47,
    progress_percentage: 44.8,
    current_item_mlb_id: 800011,
    current_item_label: 'DET at CLE — July 4, 2026',
    cancel_requested: false,
    elapsed_seconds: 252,
    estimated_remaining_seconds: 311,
    ...overrides,
  }
}

function mountComposable() {
  let api
  const wrapper = mount(
    defineComponent({
      setup() {
        api = useGameDetailsSync()
        return () => h('div')
      },
    }),
  )
  return { api, wrapper }
}

describe('useGameDetailsSync', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('starts a tracked task and sends a safe cancellation request', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: taskPayload({ status: 'queued', completed_items: 0, failed_items: 0, processed_items: 0, progress_percentage: 0 }) }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: taskPayload({ cancel_requested: true }) }) })
    vi.stubGlobal('fetch', fetchMock)
    const { api, wrapper } = mountComposable()

    await api.start({ start_date: '2026-07-01', end_date: '2026-07-07', mlb_game_id: null })
    expect(api.active.value).toBe(true)
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/admin/task_runs',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ task_name: 'mlb_game_details_sync', start_date: '2026-07-01', end_date: '2026-07-07', mlb_game_id: null }),
      }),
    )

    await api.cancel()
    expect(api.task.value.cancelRequested).toBe(true)
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      '/api/admin/task_runs/11/cancel',
      expect.objectContaining({ method: 'POST' }),
    )
    wrapper.unmount()
  })

  it('recovers an active task after reload and polls until it completes', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: [taskPayload()] }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ data: taskPayload({ status: 'completed', completed_items: 103, processed_items: 105, progress_percentage: 100, current_item_label: null }) }) })
    vi.stubGlobal('fetch', fetchMock)
    const { api, wrapper } = mountComposable()

    await api.loadActiveTask()
    expect(api.task.value).toMatchObject({ status: 'running', processedItems: 47, progressPercentage: 44.8 })

    await vi.advanceTimersByTimeAsync(1500)
    await flushPromises()
    expect(fetchMock).toHaveBeenNthCalledWith(2, '/api/admin/task_runs/11', expect.any(Object))
    expect(api.task.value.status).toBe('completed')
    expect(api.active.value).toBe(false)

    await vi.advanceTimersByTimeAsync(3000)
    expect(fetchMock).toHaveBeenCalledTimes(2)
    wrapper.unmount()
  })
})

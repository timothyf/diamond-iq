import { flushPromises } from '@vue/test-utils'
import { vi } from 'vitest'

import { useAdminTask } from '../useAdminTask'

describe('useAdminTask', () => {
  it('runs an allowlisted backend task and stores its result', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        task: 'mlb_schedule_sync',
        success: true,
        message: 'Synchronized 12 MLB games',
        data: { created_game_count: 12 },
      }),
    })
    vi.stubGlobal('fetch', fetchMock)
    const { runTask, lastResult, error } = useAdminTask()

    const response = await runTask('mlb_schedule_sync', {
      start_date: '2026-07-15',
      end_date: '2026-07-17',
    })
    await flushPromises()

    expect(response.success).toBe(true)
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/admin/tasks/mlb_schedule_sync/run',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ start_date: '2026-07-15', end_date: '2026-07-17' }),
      }),
    )
    expect(lastResult.value.message).toBe('Synchronized 12 MLB games')
    expect(lastResult.value.finishedAt).toBeTruthy()
    expect(error.value).toBe('')
  })

  it('exposes backend validation errors', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({ message: 'Start date is required' }),
      }),
    )
    const { runTask, error, lastResult } = useAdminTask()

    expect(await runTask('mlb_schedule_sync')).toBeNull()
    expect(error.value).toBe('Start date is required')
    expect(lastResult.value).toBeNull()
  })
})

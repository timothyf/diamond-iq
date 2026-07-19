import { describe, expect, it } from 'vitest'

import {
  analyticsRefreshClass,
  analyticsRefreshMessage,
  analyticsRefreshProcessing,
  deferredAnalyticsRefreshAvailable,
  failureRows,
  failureText,
  gameDetailsRefreshParameters,
  taskStatusLabel,
  workerErrorRows,
  workerPoolMessage,
} from '../gameDetailsTaskPresentation'

describe('gameDetailsTaskPresentation', () => {
  it('provides tracked-task status labels', () => {
    expect(taskStatusLabel('running')).toBe('Synchronizing')
    expect(taskStatusLabel('failed')).toBe('Completed with an error')
    expect(taskStatusLabel('waiting_for_worker')).toBe('Waiting For Worker')
  })

  it('presents analytics refresh outcomes and processing state', () => {
    const successful = { resultData: { analytics_refresh: { success: true } } }
    const skipped = { resultData: { analytics_refresh: { skipped: true } } }
    const failed = { resultData: { analytics_refresh: {} } }

    expect(analyticsRefreshMessage(successful)).toBe('Daily analytics refresh completed.')
    expect(analyticsRefreshClass(successful)).toBe('sync-progress__notice')
    expect(analyticsRefreshMessage(skipped)).toBe('Daily analytics refresh was skipped.')
    expect(analyticsRefreshMessage(failed)).toBe('Daily analytics refresh failed.')
    expect(analyticsRefreshClass(failed)).toBe('sync-progress__error')
    expect(analyticsRefreshProcessing({ status: 'running', processedItems: 12, totalItems: 12, resultData: {} })).toBe(true)
  })

  it('normalizes and deduplicates game and worker failures', () => {
    const task = {
      resultData: {
        errors: [
          { mlb_id: 823441, message: 'Lock wait timeout', errors: ['ActiveRecord::LockWaitTimeout'] },
          { mlb_id: 823441, message: 'Lock wait timeout', errors: ['ActiveRecord::LockWaitTimeout'] },
        ],
        failures: [{ message: 'Worker stopped' }],
        worker_pool_summary: {
          active_workers: 2,
          configured_workers: 4,
          games_dequeued: 50,
          games_finalized: 48,
          worker_error_count: 2,
          worker_errors: ['deadlock detected', null, 'connection lost'],
        },
      },
    }

    const failures = failureRows(task)
    expect(failures).toHaveLength(2)
    expect(failureText(failures[0])).toBe('Game 823441: Lock wait timeout (ActiveRecord::LockWaitTimeout)')
    expect(failureText(failures[1])).toBe('Worker pool: Worker stopped')
    expect(workerErrorRows(task)).toEqual(['deadlock detected', 'connection lost'])
    expect(workerPoolMessage(task)).toBe('Worker pool: 2/4 · dequeued 50 · finalized 48 · errors 2')
  })

  it('derives deferred refresh availability and date parameters', () => {
    const task = {
      taskParameters: { start_date: '2026-05-12', end_date: '2026-05-15' },
      resultData: { analytics_refresh: { deferred: true } },
    }

    expect(deferredAnalyticsRefreshAvailable(task)).toBe(true)
    expect(gameDetailsRefreshParameters(task)).toEqual({
      start_date: '2026-05-12',
      end_date: '2026-05-15',
    })
    expect(gameDetailsRefreshParameters({ taskParameters: { start_date: '2026-05-12' } })).toEqual({
      start_date: '2026-05-12',
      end_date: '2026-05-12',
    })
  })
})

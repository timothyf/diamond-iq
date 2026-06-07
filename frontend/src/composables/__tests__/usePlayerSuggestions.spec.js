import { computed } from 'vue'
import { flushPromises } from '@vue/test-utils'
import { afterEach, beforeEach, vi } from 'vitest'

import { usePlayerSuggestions } from '../usePlayerSuggestions'

describe('usePlayerSuggestions', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('fetches matching player suggestions by combined name query', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [
          {
            id: 42,
            first_name: 'Miguel',
            last_name: 'Cabrera',
            team: { abbreviation: 'DET' },
          },
        ],
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const query = computed(() => ({
      name: 'mig',
      teamId: 1,
      perPage: 6,
    }))

    const { suggestions, loading, error } = usePlayerSuggestions(query)

    await vi.advanceTimersByTimeAsync(180)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/players?per_page=6&sort=last_name&filter%5Bname%5D=mig&filter%5Bteam_id%5D=1',
      {
        headers: {
          Accept: 'application/json',
        },
      },
    )
    expect(suggestions.value).toEqual([
      {
        id: 42,
        firstName: 'Miguel',
        lastName: 'Cabrera',
        fullName: 'Miguel Cabrera',
        team: { abbreviation: 'DET' },
      },
    ])
    expect(loading.value).toBe(false)
    expect(error.value).toBe('')
  })

  it('does not fetch when the query is too short', async () => {
    const fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)

    const query = computed(() => ({
      name: 'm',
    }))

    const { suggestions } = usePlayerSuggestions(query)

    await vi.advanceTimersByTimeAsync(180)
    await flushPromises()

    expect(fetchMock).not.toHaveBeenCalled()
    expect(suggestions.value).toEqual([])
  })
})

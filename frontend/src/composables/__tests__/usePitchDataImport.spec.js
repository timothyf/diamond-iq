import { flushPromises } from '@vue/test-utils'

import { usePitchDataImport } from '../usePitchDataImport'

describe('usePitchDataImport', () => {
  it('uploads a csv file and returns an import summary', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        message: 'Imported 120 pitch data rows',
        data: {
          imported_count: 120,
          duplicate_count: 4,
          skipped_count: 2,
        },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const { importFile, uploading, error, summary } = usePitchDataImport()
    const file = new File(['game_pk,at_bat_number,pitch_number'], 'pitch-data.csv', { type: 'text/csv' })

    const payload = await importFile(file)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(fetchMock.mock.calls[0][0]).toBe('/api/pitch_data/import')
    expect(fetchMock.mock.calls[0][1]).toMatchObject({
      method: 'POST',
      headers: { Accept: 'application/json' },
    })
    expect(fetchMock.mock.calls[0][1].body).toBeInstanceOf(FormData)
    expect(payload.message).toBe('Imported 120 pitch data rows')
    expect(uploading.value).toBe(false)
    expect(error.value).toBe('')
    expect(summary.value).toBe('Imported 120 pitch data rows Collapsed 4 duplicate pitch rows. Skipped 2 invalid rows.')
  })

  it('surfaces an import error when the request fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({
          message: 'Missing required columns: game_pk, at_bat_number, pitch_number',
        }),
      }),
    )

    const { importFile, error, summary } = usePitchDataImport()
    const file = new File(['pitch_type,events'], 'pitch-data.csv', { type: 'text/csv' })

    const payload = await importFile(file)
    await flushPromises()

    expect(payload).toBeNull()
    expect(summary.value).toBe('')
    expect(error.value).toBe('Missing required columns: game_pk, at_bat_number, pitch_number')
  })
})

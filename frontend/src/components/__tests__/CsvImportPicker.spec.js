import { mount } from '@vue/test-utils'
import { nextTick } from 'vue'

import CsvImportPicker from '../CsvImportPicker.vue'

function buildFile(name, type = 'text/csv', contents = 'season,player\n2024,Example') {
  return new File([contents], name, { type })
}

async function selectFile(wrapper, file) {
  const input = wrapper.find('input[type="file"]')

  Object.defineProperty(input.element, 'files', {
    configurable: true,
    value: [file],
  })

  await input.trigger('change')
  await nextTick()
}

describe('CsvImportPicker', () => {
  it('emits the selected CSV file and displays its name', async () => {
    const wrapper = mount(CsvImportPicker)
    const file = buildFile('season-stats.csv')

    await selectFile(wrapper, file)

    expect(wrapper.emitted('file-selected')).toHaveLength(1)
    expect(wrapper.emitted('file-selected')[0][0]).toBe(file)
    expect(wrapper.text()).toContain('season-stats.csv')
  })

  it('rejects non-csv files', async () => {
    const wrapper = mount(CsvImportPicker)
    const file = buildFile('notes.txt', 'text/plain', 'not,csv')

    await selectFile(wrapper, file)

    expect(wrapper.emitted('file-selected')).toBeUndefined()
    expect(wrapper.text()).toContain('Please choose a file with a .csv extension.')
  })

  it('emits an import-request payload for the selected file', async () => {
    const wrapper = mount(CsvImportPicker)
    const file = buildFile('batting.csv')

    await selectFile(wrapper, file)

    const prepareButton = wrapper.find('[data-test="execute-import"]')
    await prepareButton.trigger('click')

    expect(wrapper.emitted('import-request')).toHaveLength(1)
    expect(wrapper.emitted('import-request')[0][0]).toEqual({
      file,
      replaceSeason: false,
    })
  })

  it('includes replaceSeason=true when the checkbox is checked', async () => {
    const wrapper = mount(CsvImportPicker)
    const file = buildFile('batting.csv')

    await selectFile(wrapper, file)

    const checkbox = wrapper.find('input[type="checkbox"]')
    await checkbox.setValue(true)

    const prepareButton = wrapper.find('[data-test="execute-import"]')
    await prepareButton.trigger('click')

    expect(wrapper.emitted('import-request')).toHaveLength(1)
    expect(wrapper.emitted('import-request')[0][0]).toEqual({
      file,
      replaceSeason: true,
    })
  })

  it('renders a progress indicator while an import is in flight', async () => {
    const wrapper = mount(CsvImportPicker, {
      props: {
        busy: true,
      },
    })

    expect(wrapper.text()).toContain('Importing CSV into the Rails datastore…')
    expect(wrapper.find('[role="progressbar"]').exists()).toBe(true)
    expect(wrapper.find('.import-progress__note').text()).toContain('Large historical files can take a little time')
  })
})

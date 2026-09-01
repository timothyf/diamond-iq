import { expect, test } from '@playwright/test'

const editor = {
  email: 'e2e.editor@ninelens.test',
  password: 'playwright-password-123',
}

async function signIn(page) {
  await page.goto('/login')
  await page.getByLabel('Email').fill(editor.email)
  await page.getByLabel('Password').fill(editor.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/$/)
}

async function openE2EPlayer(page) {
  const search = page.getByRole('combobox', { name: 'Find a player or team' })
  await search.fill('E2E Slugger')
  await page.locator('#player-search-results').getByRole('button').filter({ hasText: 'E2E Slugger' }).click()
  await expect(page).toHaveURL(/\/players\/\d+$/)
  await expect(page.getByRole('heading', { name: 'E2E Slugger', exact: true })).toBeVisible()
}

test('creates a saved player analysis and a player note', async ({ page }) => {
  const suffix = Date.now()
  const savedViewName = `E2E saved player review ${suffix}`
  const noteBody = `E2E scouting observation ${suffix}`

  await signIn(page)
  await openE2EPlayer(page)

  await page.getByRole('tab', { name: 'Performance Trends' }).click()
  const savedAnalysis = page.getByTestId('saved-analysis-controls')
  await expect(savedAnalysis).toBeVisible()
  await savedAnalysis.getByLabel('Saved view name').fill(savedViewName)
  await savedAnalysis.getByLabel('Saved view sharing').selectOption('organization')
  await savedAnalysis.getByRole('button', { name: 'Save current' }).click()
  await expect(savedAnalysis).toContainText(savedViewName)
  await expect(savedAnalysis).toContainText('organization')

  await page.getByRole('tab', { name: 'Notes' }).click()
  const notes = page.getByTestId('notes-panel')
  await expect(notes).toBeVisible()
  await notes.getByPlaceholder('Record an observation, decision, or follow-up…').fill(noteBody)
  await notes.getByLabel('Tags').fill('e2e, follow-up')
  await notes.getByRole('button', { name: 'Add note' }).click()
  await expect(notes).toContainText(noteBody)
  await expect(notes).toContainText('e2e')
  await expect(notes).toContainText('follow-up')
})

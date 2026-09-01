import { expect, test } from '@playwright/test'

const homeLeader = 'E2E Slugger'
const comparisonPlayer = 'E2E Rival'

test('opens a Home leader profile and compares that player with another player', async ({ page }) => {
  await page.goto('/')

  const homeRunsCard = page.locator('.leader-card').filter({
    has: page.getByRole('heading', { name: 'Home runs', exact: true }),
  })
  await homeRunsCard.getByRole('link', { name: new RegExp(`^${homeLeader}\\b`) }).click()

  await expect(page).toHaveURL(/\/players\/\d+$/)
  await expect(page.getByRole('heading', { name: homeLeader, exact: true })).toBeVisible()

  await page.getByTestId('compare-player-link').click()

  await expect(page).toHaveURL(/\/compare\?left=\d+$/)
  await expect(page.getByText('Choose at least two different players to begin the comparison.')).toBeVisible()

  const playerBPicker = page.getByTestId('comparison-picker-player b')
  await playerBPicker.getByPlaceholder('Search player b…').fill(comparisonPlayer)
  await playerBPicker.getByRole('button', { name: new RegExp(comparisonPlayer) }).click()

  await expect(page).toHaveURL(/\/compare\?left=\d+&right=\d+$/)
  await expect(page.getByTestId('comparison-identities')).toContainText(homeLeader)
  await expect(page.getByTestId('comparison-identities')).toContainText(comparisonPlayer)
  await expect(page.getByTestId('season-comparison')).toBeVisible()
  await expect(page.getByTestId('career-comparison')).toBeVisible()
})

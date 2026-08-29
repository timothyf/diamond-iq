import { expect, test } from '@playwright/test'

const accounts = {
  viewer: {
    email: 'e2e.viewer@ninelens.test',
    password: 'playwright-password-123',
  },
  administrator: {
    email: 'e2e.admin@ninelens.test',
    password: 'playwright-password-123',
  },
}

async function signIn(page, account) {
  await page.goto('/login')
  await page.getByLabel('Email').fill(account.email)
  await page.getByLabel('Password').fill(account.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/$/)
}

test.describe('sign-in and role-based access', () => {
  test('redirects anonymous users to sign in before viewing watchlists', async ({ page }) => {
    await page.goto('/watchlists')

    await expect(page).toHaveURL(/\/login\?redirect=\/watchlists/)
    await expect(page.getByRole('heading', { name: 'Sign in to NineLens' })).toBeVisible()
  })

  test('allows a viewer to sign in and use watchlists but blocks Admin', async ({ page }) => {
    await signIn(page, accounts.viewer)

    await page.goto('/watchlists')
    await expect(page.getByRole('heading', { name: 'Watchlists & acquisition evaluations' })).toBeVisible()

    await page.goto('/admin')
    await expect(page).toHaveURL(/\/access-denied$/)
    await expect(page.getByRole('heading', { name: 'Administrator access required' })).toBeVisible()
  })

  test('allows an administrator to access Admin after sign in', async ({ page }) => {
    await signIn(page, accounts.administrator)

    await page.goto('/admin')
    await expect(page).toHaveURL(/\/admin$/)
    await expect(page.getByRole('heading', { name: 'Data administration' })).toBeVisible()
  })
})

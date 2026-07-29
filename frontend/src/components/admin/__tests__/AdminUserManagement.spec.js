import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import AdminUserManagement from '../AdminUserManagement.vue'

describe('AdminUserManagement', () => {
  it('lists users and supports role and account-status changes', async () => {
    let target = {
      id: 2,
      name: 'Scout User',
      email: 'scout@example.test',
      role: 'scout',
      role_label: 'Scout',
      disabled: false,
      system_account: false,
      current_user: false,
      last_signed_in_at: null,
    }
    const admin = {
      id: 1,
      name: 'Admin User',
      email: 'admin@example.test',
      role: 'administrator',
      role_label: 'Administrator',
      disabled: false,
      system_account: false,
      current_user: true,
      last_signed_in_at: '2026-07-29T12:00:00Z',
    }
    const roles = ['administrator', 'analyst', 'coach', 'scout', 'viewer']
      .map((value) => ({ value, label: value[0].toUpperCase() + value.slice(1) }))

    vi.stubGlobal('fetch', vi.fn(async (url, options = {}) => {
      if (options.method === 'PATCH') {
        const changes = JSON.parse(options.body)
        target = { ...target, ...changes }
        return { ok: true, json: async () => ({ data: target }) }
      }
      return {
        ok: true,
        json: async () => ({
          data: [admin, target],
          meta: {
            active_count: target.disabled ? 1 : 2,
            disabled_count: target.disabled ? 1 : 0,
            administrator_count: 1,
            roles,
          },
        }),
      }
    }))
    vi.spyOn(window, 'confirm').mockReturnValue(true)

    const wrapper = mount(AdminUserManagement)
    await flushPromises()

    expect(wrapper.text()).toContain('Scout User')
    expect(wrapper.text()).toContain('2Active accounts')

    await wrapper.get('[data-test="admin-user-2"] select').setValue('analyst')
    await flushPromises()
    expect(target.role).toBe('analyst')

    await wrapper.get('[data-test="admin-user-2"] .user-actions button:first-child').trigger('click')
    await flushPromises()
    expect(target.disabled).toBe(true)
    expect(wrapper.get('[data-test="admin-user-2"]').text()).toContain('Disabled')
  })

  it('shows the one-time password returned by an access reset', async () => {
    const target = {
      id: 2,
      name: 'Coach User',
      email: 'coach@example.test',
      role: 'coach',
      disabled: false,
      system_account: false,
      current_user: false,
      last_signed_in_at: null,
    }
    vi.stubGlobal('fetch', vi.fn(async (url, options = {}) => {
      if (String(url).endsWith('/reset_access') && options.method === 'POST') {
        return {
          ok: true,
          json: async () => ({
            data: { ...target, temporary_password: 'temporary-access-123' },
            meta: { message: 'Shown only once.' },
          }),
        }
      }
      return {
        ok: true,
        json: async () => ({
          data: [target],
          meta: {
            active_count: 1,
            disabled_count: 0,
            administrator_count: 1,
            roles: [{ value: 'coach', label: 'Coach' }],
          },
        }),
      }
    }))
    vi.spyOn(window, 'confirm').mockReturnValue(true)

    const wrapper = mount(AdminUserManagement)
    await flushPromises()
    await wrapper.get('[data-test="admin-user-2"] .user-actions button:last-child').trigger('click')
    await flushPromises()

    expect(wrapper.get('[data-test="temporary-access"]').text()).toContain('temporary-access-123')
    expect(wrapper.get('[data-test="temporary-access"]').text()).toContain('Shown only once.')
  })
})

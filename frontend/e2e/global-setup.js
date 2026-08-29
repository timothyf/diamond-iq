import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const backendDirectory = fileURLToPath(new URL('../../backend', import.meta.url))
const e2ePassword = 'playwright-password-123'
const rubyBinPath = '/Users/timothyfisher/.rvm/gems/ruby-3.2.3/bin:/Users/timothyfisher/.rvm/gems/ruby-3.2.3@global/bin:/Users/timothyfisher/.rvm/rubies/ruby-3.2.3/bin'
const seedUsers = `
  [
    { email: 'e2e.viewer@ninelens.test', name: 'E2E Viewer', role: 'viewer' },
    { email: 'e2e.admin@ninelens.test', name: 'E2E Administrator', role: 'administrator' }
  ].each do |attributes|
    user = User.find_or_initialize_by(email: attributes.fetch(:email))
    user.assign_attributes(attributes.merge(disabled_at: nil, system_account: false))
    user.password = '${e2ePassword}'
    user.save!
  end
`

function rails(...argumentsList) {
  execFileSync('bundle', ['exec', 'rails', ...argumentsList], {
    cwd: backendDirectory,
    env: { ...process.env, PATH: `${rubyBinPath}:${process.env.PATH}`, RAILS_ENV: 'test' },
    stdio: 'inherit',
  })
}

export default function globalSetup() {
  rails('db:prepare')
  rails('runner', seedUsers)
}

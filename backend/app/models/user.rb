class User < ApplicationRecord
  ROLES = %w[administrator analyst coach scout viewer admin editor].freeze
  PASSWORD_ITERATIONS = 120_000

  has_many :owned_watchlists, class_name: "Watchlist", foreign_key: :owner_id, dependent: :nullify
  has_many :owned_need_profiles, class_name: "NeedProfile", foreign_key: :owner_id, dependent: :nullify
  has_many :owned_lineup_scenarios, class_name: "LineupScenario", foreign_key: :owner_id, dependent: :restrict_with_error
  has_many :owned_opponent_reports, class_name: "OpponentReport", foreign_key: :owner_id, dependent: :restrict_with_error
  has_many :audit_logs, dependent: :nullify

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 8 }, allow_nil: true, on: :create

  scope :active, -> { where(disabled_at: nil) }

  attr_reader :password

  before_validation :normalize_email

  def password=(value)
    @password = value.to_s
    self.password_salt = SecureRandom.hex(16)
    self.password_digest = digest_password(@password, password_salt)
  end

  def authenticate_password(value)
    return false if password_digest.blank? || password_salt.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      digest_password(value.to_s, password_salt), password_digest
    )
  end

  def issue_auth_token!
    raw_token = SecureRandom.urlsafe_base64(48)
    update!(auth_token_digest: Digest::SHA256.hexdigest(raw_token))
    raw_token
  end

  def revoke_auth_token!
    update!(auth_token_digest: nil)
  end

  def admin?
    role.in?(%w[admin administrator])
  end

  def active_for_sign_in?
    disabled_at.nil?
  end

  def can_write?
    admin? || role.in?(%w[analyst coach scout editor])
  end

  def role_label
    { "admin" => "Administrator", "editor" => "Scout" }.fetch(role, role.to_s.titleize)
  end

  def can_manage?(record)
    admin? || (can_write? && record.respond_to?(:owner_id) && record.owner_id == id)
  end

  private

  def digest_password(value, salt)
    OpenSSL::KDF.pbkdf2_hmac(value, salt: salt, iterations: PASSWORD_ITERATIONS, length: 32, hash: "SHA256").unpack1("H*")
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end

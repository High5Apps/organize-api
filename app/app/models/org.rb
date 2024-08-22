class Org < ApplicationRecord
  include Encryptable

  MAX_EMAIL_LENGTH = 100
  MAX_NAME_LENGTH = 35
  MAX_MEMBER_DEFINITION_LENGTH = 75

  has_many :permissions
  has_many :posts
  has_many :users

  has_many :ballots, through: :users
  has_many :comments, through: :posts
  has_many :flags, through: :users
  has_many :moderation_events, through: :users,
    source: :created_moderation_events
  has_many :terms, through: :users
  has_many :upvotes, through: :users

  has_encrypted :name, present: true, max_length: MAX_NAME_LENGTH
  has_encrypted :member_definition,
    present: true,
    max_length: MAX_MEMBER_DEFINITION_LENGTH

  validates :email,
    presence: true,
    format: URI::MailTo::EMAIL_REGEXP,
    length: { maximum: MAX_EMAIL_LENGTH },
    uniqueness: true
  validates :email, format: { without: /[A-Z\s]/ }

  before_validation :normalize_email

  def graph
    connections = Connection.where(scanner_id: user_ids).or(
      Connection.where(sharer_id: user_ids)
    ).pluck :sharer_id, :scanner_id

    blocked_user_ids = users.blocked.ids
    left_org_user_ids = users.left_org.ids

    { blocked_user_ids:, connections:, left_org_user_ids:, user_ids: }
  end

  def next_pseudonym
    seed = id.gsub("-", "").hex
    user_count = users.count
    User::Pseudonym.new(seed).at(user_count)
  end

  private

  def normalize_email
    self.email = email&.strip&.downcase
  end
end

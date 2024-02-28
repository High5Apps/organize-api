class Comment < ApplicationRecord
  include Encryptable

  scope :created_at_or_before, ->(time) { where(created_at: ..time) }
  scope :includes_my_vote_from_upvotes_created_at_or_before, ->(time, my_id) {
    # Even though there is at most one most_recent_upvote per requester per
    # comment, SUM is used because an aggregate function is required
    left_outer_joins_with_most_recent_upvotes_created_at_or_before(time)
      .select(Comment.sanitize_sql_array([
        "SUM(CASE WHEN upvotes.user_id = :my_id THEN value ELSE 0 END) AS my_vote",
        my_id:]))
  }
  scope :includes_pseudonym, -> {
    select(:pseudonym).joins(:user).group(:id, :pseudonym)
  }
  scope :includes_score_from_upvotes_created_at_or_before, ->(time) {
    left_outer_joins_with_most_recent_upvotes_created_at_or_before(time)
      .select('COALESCE(SUM(value), 0) AS score')
  }
  scope :left_outer_joins_with_most_recent_upvotes_created_at_or_before, ->(time) {
    joins(%Q(
      LEFT OUTER JOIN (
        #{Upvote.most_recent_created_at_or_before(time).to_sql}
      ) AS upvotes
        ON upvotes.comment_id = comments.id
    ).gsub(/\s+/, ' '))
  }
  scope :order_by_hot_created_at_or_before, ->(time) {
    left_outer_joins_with_most_recent_upvotes_created_at_or_before(time)
      .order(Arel.sql(Comment.sanitize_sql_array([
        %(
          (1 + COALESCE(SUM(value), 0)) /
          (2 +
            (EXTRACT(EPOCH FROM (:cutoff_time - comments.created_at)) /
            :time_division)
          )^:gravity DESC, comments.id DESC
        ).gsub(/\s+/, ' '),
        cutoff_time: time,
        gravity: 0.975,
        time_division: 1.hour])))
      .group(:id)
  }

  MAX_BODY_LENGTH = 10000
  MAX_COMMENT_DEPTH = 8

  belongs_to :post
  belongs_to :user

  has_many :upvotes

  validates :post, presence: true
  validates :user, presence: true
  validates :depth,
    numericality: {
      greater_than_or_equal_to: 0,
      less_than: MAX_COMMENT_DEPTH,
      only_integer: true,
    }

  after_create :create_upvote_for_user

  has_encrypted :body, present: true, max_length: MAX_BODY_LENGTH

  has_ancestry cache_depth: true, depth_cache_column: :depth

  private

  def create_upvote_for_user
    upvotes.create! user:, value: 1
  end
end

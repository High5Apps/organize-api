class Post::Query
  ALLOWED_ATTRIBUTES = {
    id: '',
    category: '',
    title: '',
    body: '',
    user_id: '',
    created_at: '',
    pseudonym: '',
    score: '',
    my_vote: '',
  }

  FAR_FUTURE_TIME = 1.year.from_now.freeze
  UP_VOTE_JOIN_TEMPLATE = %(
    LEFT OUTER JOIN (
      SELECT *
      FROM (
        SELECT *,
          FIRST_VALUE(up_votes.id) OVER (
            PARTITION BY up_votes.user_id, up_votes.post_id
            ORDER BY up_votes.created_at DESC, up_votes.id DESC
          ) AS first_id
        FROM up_votes
        WHERE up_votes.created_at < :created_before
      ) AS recent_up_votes
      WHERE recent_up_votes.id = first_id
    ) AS most_recent_upvotes
      ON most_recent_upvotes.post_id = posts.id
  ).gsub(/\s+/, ' ').freeze
  private_constant :FAR_FUTURE_TIME, :UP_VOTE_JOIN_TEMPLATE

  def self.build(params={}, initial_posts: nil)
    initial_posts ||= Post.all

    created_before_param = params[:created_before] || FAR_FUTURE_TIME
    created_before = Time.at(created_before_param.to_f).utc

    posts = initial_posts
      .created_before(created_before)
      .joins(:user)
      .joins(Post.sanitize_sql_array([
        UP_VOTE_JOIN_TEMPLATE, created_before: created_before,
      ]))
      .page(params[:page])
      .group(:id, :pseudonym)
      .select(*selections(params))

    category_parameter = params[:category]
    if category_parameter == 'general'
      posts = posts.general
    elsif category_parameter == 'grievances'
      posts = posts.grievances
    elsif category_parameter == 'demands'
      posts = posts.demands
    end

    created_after_param = params[:created_after]
    if created_after_param
      created_after = Time.at(created_after_param.to_f).utc
      posts = posts.created_after(created_after)
    end

    # Default to sorting by new
    sort_parameter = params[:sort] || 'new'
    if sort_parameter == 'new'
      posts = posts.order(created_at: :desc, id: :desc)
    elsif sort_parameter == 'old'
      posts = posts.order(created_at: :asc, id: :asc)
    elsif sort_parameter == 'top'
      posts = posts.order(score: :desc, id: :desc)
    end

    posts
  end

  private

  def self.selections(params)
    score = 'COALESCE(SUM(value), 0) AS score'

    # Even though there is at most one most_recent_upvote per requester per
    # post, SUM is used because an aggregate function is required
    my_vote = Post.sanitize_sql_array([
      "SUM(CASE WHEN most_recent_upvotes.user_id = :requester_id THEN value ELSE 0 END) AS my_vote",
      requester_id: params[:requester_id]])

    attributes = ALLOWED_ATTRIBUTES.merge(my_vote: my_vote, score: score)
    attributes.map { |k,v| (v.blank?) ? k : v }
  end
end

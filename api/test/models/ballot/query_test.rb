class BallotQueryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'should respect initial_posts' do
    org = @user.org
    assert_not_equal Ballot.count, org.ballots.count
    ballot_ids = Ballot::Query.build(org.ballots).ids
    ballots = Ballot.find(ballot_ids)
    assert ballots.all? { |ballot| ballot.org == org }
  end

  test 'should only include allow-listed attributes' do
    ballots = Ballot::Query.build(@user.org.ballots)
    ballot_json = ballots.first.as_json.with_indifferent_access

    attribute_allow_list = Ballot::Query::ALLOWED_ATTRIBUTES

    attribute_allow_list.each do |attribute|
      assert ballot_json.key?(attribute)
    end

    assert_equal attribute_allow_list.count, ballot_json.keys.count
  end

  test 'should respect created_at_or_before param' do
    ballot = ballots(:two)
    ballots = Ballot::Query.build Ballot.all,
      created_at_or_before: ballot.created_at.iso8601(6)
    assert_not_equal Ballot.all.to_a.count, ballots.to_a.count
    assert_equal Ballot.created_at_or_before(ballot.created_at).sort,
      ballots.sort
  end

  test 'should respect active_at param' do
    ballot = ballots(:two)
    ballots = Ballot::Query.build Ballot.all,
      active_at: ballot.voting_ends_at.iso8601(6)
    assert_not_equal Ballot.all.to_a.count, ballots.to_a.count
    assert_equal Ballot.active_at(ballot.voting_ends_at).sort, ballots.sort
  end

  test 'should respect inactive_at param' do
    ballot = ballots(:two)
    ballots = Ballot::Query.build Ballot.all,
      inactive_at: ballot.voting_ends_at.iso8601(6)
    assert_not_equal Ballot.all.to_a.count, ballots.to_a.count
    assert_equal Ballot.inactive_at(ballot.voting_ends_at).sort, ballots.sort
  end

  test 'should order posts by active by default' do
    ballot_ids = Ballot::Query.build(Ballot.all).pluck :id
    assert_not_empty ballot_ids
    assert_equal Ballot.order_by_active(Time.now).pluck(:id), ballot_ids
  end

  test 'active sort param should order ballots by active with active_at defaulting to now' do
    ballot_ids = Ballot::Query.build(Ballot.all, sort: 'active').pluck :id
    assert_not_empty ballot_ids
    now = Time.now
    assert_equal Ballot.active_at(now).order_by_active(now).pluck(:id),
      ballot_ids
  end

  test 'inactive sort param should order ballots by inactive with inactive_at defaulting to now' do
    ballot_ids = Ballot::Query.build(Ballot.all, sort: 'inactive').pluck :id
    assert_not_empty ballot_ids
    assert_equal Ballot.inactive_at(Time.now).order_by_inactive.pluck(:id),
      ballot_ids
  end
end

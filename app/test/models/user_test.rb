require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user_without_org = users(:two)
  end

  test 'should be valid' do
    assert @user.valid?
  end

  test 'org should be optional' do
    assert_nil @user_without_org.org
    assert @user_without_org.valid?
  end

  test 'public_key_bytes should be present' do
    @user.public_key_bytes = nil
    assert_not @user.valid?
  end

  test 'public_key_bytes should have the correct length' do
    @user.public_key_bytes = Base64.decode64('deadbeef')
    assert_not @user.valid?
  end

  test 'should set pseudonym when org_id is initially set' do
    assert_nil @user_without_org.pseudonym
    @user_without_org.update!(org: orgs(:one))
    assert_not_nil @user_without_org.reload.pseudonym
  end

  test 'should set joined_at when org_id is initially set' do
    assert_nil @user_without_org.joined_at
    @user_without_org.update!(org: orgs(:one))
    assert_not_nil @user_without_org.reload.joined_at
  end

  test 'should create a founder term when org is created and set on creator' do
    org = orgs :one
    @user_without_org.create_org org.attributes.except 'id'
    assert_difference 'Term.count', 1 do
      @user_without_org.save
    end
  end

  test "my_vote_candidate_ids should return user's most recently created vote's candidate_ids" do
    ballot_with_vote = ballots(:one)
    my_vote_candidate_ids = @user.my_vote_candidate_ids(ballot_with_vote)
    assert_equal votes(:one).candidate_ids, my_vote_candidate_ids
  end

  test 'my_vote_candidate_ids should return [] when user has not voted on ballot' do
    ballot_without_vote = ballots(:three)
    assert_equal [], @user.my_vote_candidate_ids(ballot_without_vote)
  end

  test 'joined_before should include users where joined_at is in the past' do
    u1, u2, u3 = create_users_with_joined_at(
      [1.second.from_now, 2.seconds.from_now, 3.seconds.from_now])
    query = User.joined_before u2.joined_at
    assert query.exists? id: u1
    assert_not query.exists? id: u2
    assert_not query.exists? id: u3
  end

  private

  def create_users_with_joined_at(joined_ats)
    public_key_bytes = users(:one).public_key_bytes
    org = orgs(:one).dup
    org.save!

    joined_ats.map do |joined_at|
      travel_to joined_at do
        user = User.create!(public_key_bytes:)
        user.update!(org:)
        user
      end
    end
  end
end

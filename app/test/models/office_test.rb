require "test_helper"

class OfficeTest < ActiveSupport::TestCase
  setup do
    @org = orgs :two
    @user = @org.users.first
    @election = ballots :election_one
    @term = terms :three
  end

  test 'availability should include all offices when office param absent' do
    assert_equal Office::TYPE_STRINGS.sort,
      Office.availability_in(@org).map{ |o| o[:type] }.sort
  end

  test 'availability should filter by office param when present' do
    Office::TYPE_STRINGS.each do |office|
      assert_equal office, Office.availability_in(@org, office)[:type]
    end
  end

  test 'availability should throw unless office param is a String' do
    assert_raises do
      Office.availability_in(@org, :founder)
    end
  end

  test 'availability should be open if there is no active term or election' do
    assert_empty @org.ballots.election
    assert_equal ['founder'], @org.terms.pluck(:office)
    assert_availability_open_except_for ['founder']
  end

  test 'availability should not be open if there is an active election' do
    (Office::TYPE_STRINGS - ['founder']).each do |office|
      attributes = @election.attributes.merge \
        id: nil, office:, user_id: @user.id
      ballot = @user.ballots.create! attributes
      assert_availability_open_except_for ['founder', ballot.office]
      ballot.destroy!
    end
  end

  test 'availability should not be open if there is an election awaiting term acceptance by a winner' do
    org = orgs :one
    election = destroy_all_elections_but_one org

    travel_to election.voting_ends_at + 1.second do
      assert_not_empty election.winners

      Office::TYPE_STRINGS.each do |office|
        election.update!(office:)
        assert_availability_open_except_for([office], org:)
      end
    end
  end

  test 'availability should not be affected if there is an election awaiting term acceptance but no winner exists' do
    org = orgs :one
    election = destroy_all_elections_but_one org
    election.votes.destroy_all
    travel_to election.voting_ends_at + 1.second do
      assert_empty election.winners

      Office::TYPE_STRINGS.each do |office|
        election.update!(office:)
        assert_availability_open_except_for([], org:)
      end
    end
  end

  test 'availability for non-stewards should not be open if there is a term outside cooldown' do
    (Office::TYPE_STRINGS - ['founder', 'steward']).each do |office|
      attributes = @term.attributes.merge id: nil, office:, user_id: @user.id
      term = @user.terms.build attributes

      # Can't validate because the user didn't actually win an election
      term.save! validate: false

      travel_to term.ends_at - Term::COOLDOWN_PERIOD
      assert_availability_open_except_for ['founder']
      travel -1.second
      assert_availability_open_except_for ['founder', term.office]
      term.destroy!
    end
  end

  test 'availability for stewards should disregard if there is a term outside cooldown' do
    office = 'steward'
    attributes = @term.attributes.merge id: nil, office:, user_id: @user.id
    term = @user.terms.build attributes

    # Can't validate because the user didn't actually win an election
    term.save! validate: false

    travel_to term.ends_at - Term::COOLDOWN_PERIOD
    assert_availability_open_except_for ['founder']
    travel -1.second
    assert_availability_open_except_for ['founder']
  end

  private

  def assert_availability_open_except_for offices, org: nil
    org ||= @org
    assert_equal offices.sort,
      Office.availability_in(org)
        .filter { |o| !o[:open] }.map { |o| o[:type] }.sort
  end

  def destroy_all_elections_but_one org
    org.terms.each { |term| term.destroy! }
    election = org.ballots.election.first
    org.ballots.election.where.not(id: election.id).each do |election|
      election.votes.destroy_all
      election.candidates.destroy_all
      election.nominations.destroy_all
      election.destroy!
    end

    election
  end
end

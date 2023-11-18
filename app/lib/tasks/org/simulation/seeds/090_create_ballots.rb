# The Pareto distribution below is unbounded and can sometimes be more than
# 1000. This cap helps to guard against those rare and unrealistic scenarios.
BALLOT_DISTRIBUTION_MAX = 30

BALLOTS_DISTRIBUTION = -> { [(1/rand).round, BALLOT_DISTRIBUTION_MAX].min }

QUESTION_CHARACTER_RANGE = 20..Ballot::MAX_QUESTION_LENGTH

def hipster_ipsum_ballot_question
  question_length = rand QUESTION_CHARACTER_RANGE
  question = Faker::Hipster.paragraph_by_chars(characters: question_length)
    .delete('.') # Remove all periods
    .downcase
    .split[...-1] # Remove last word to ensure no partial words
    .join ' '
  "Should we #{question}?"
end

def create_fake_ballot(org, category:, isActive:)
  created_at = Faker::Time.between from: $simulation.started_at,
    to: $simulation.ended_at

  voting_ends_at = if isActive
    Faker::Time.between from: $simulation.ended_at,
      to: $simulation.ended_at + 2.weeks
  else
    Faker::Time.between from: created_at, to: $simulation.ended_at
  end

  encrypted_question = $simulation.encrypt hipster_ipsum_ballot_question

  Timecop.freeze created_at do
    org.ballots.create! category: category,
      encrypted_question: encrypted_question,
      voting_ends_at: voting_ends_at
  end
end

inactive_yes_no_ballot_count = BALLOTS_DISTRIBUTION.call
active_yes_no_ballot_count = BALLOTS_DISTRIBUTION.call
ballot_count = [
  inactive_yes_no_ballot_count,
  active_yes_no_ballot_count,
].sum

print "\tCreating #{ballot_count} ballots... "
start_time = Time.now

org = User.find($simulation.founder_id).org

inactive_yes_no_ballot_count.times do
  create_fake_ballot org, category: 'yes_no', isActive: false
end

active_yes_no_ballot_count.times do
  create_fake_ballot org, category: 'yes_no', isActive: true
end

puts "Completed in #{(Time.now - start_time).round 3} s"

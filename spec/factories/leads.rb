FactoryBot.define do
  factory :lead do
    temperature    { Lead::TEMPERATURES.sample }
    interest_rating { rand(1..5) }
    status         { Lead::STATUSES.sample }
    scanned_at     { Time.current }
    association :visitor
    association :stall_owner
    association :event
  end
end

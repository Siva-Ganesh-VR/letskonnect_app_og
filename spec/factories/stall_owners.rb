FactoryBot.define do
  factory :stall_owner do
    name          { Faker::Name.full_name }
    mobile_number { "9#{Faker::Number.number(digits: 9)}" }
    company_name  { Faker::Company.name }
    stall_number  { "#{["A", "B", "C"].sample}#{rand(1..20)}" }
    stall_category { ["IT Services", "Finance", "Marketing", "Education"].sample }
    password      { "Password@123" }
    active        { true }
    association :event

    after(:build) { |s| s.jti ||= SecureRandom.uuid }
  end
end

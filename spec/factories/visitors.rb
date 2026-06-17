FactoryBot.define do
  factory :visitor do
    full_name         { Faker::Name.full_name }
    mobile_number     { "9#{Faker::Number.number(digits: 9)}" }
    location          { Faker::Address.city }
    profession        { Faker::Job.title }
    business_name     { Faker::Company.name }
    business_category { ["IT Services", "Finance", "Education", "Healthcare", "Retail"].sample }
    mobile_verified   { false }
    association       :event

    trait :verified do
      mobile_verified { true }
    end
  end
end

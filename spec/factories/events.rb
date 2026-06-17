FactoryBot.define do
  factory :event do
    name       { Faker::Lorem.words(number: 3).join(" ").titleize + " Expo" }
    venue      { Faker::Address.street_address }
    city       { "Chennai" }
    start_date { Date.today + 7.days }
    end_date   { Date.today + 9.days }
    status     { "active" }
    association :event_organizer

    after(:build) do |event|
      event.registration_qr_token ||= SecureRandom.urlsafe_base64(32)
      event.slug ||= "#{event.name.parameterize}-#{SecureRandom.hex(4)}"
    end
  end
end

class Feedback < ApplicationRecord
  belongs_to :event
  belongs_to :visitor

  validates :overall_rating,
            :organization_rating,
            :venue_rating,
            :exhibitor_rating,
            presence: true,
            inclusion: { in: 1..5 }

  validates :recommend, inclusion: { in: [true, false] }

  validates :visitor_id,
            uniqueness: {
              scope: :event_id,
              message: "has already submitted feedback for this event"
            }
end
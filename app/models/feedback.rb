class Feedback < ApplicationRecord
  belongs_to :event
  belongs_to :visitor

  validates :overall_rating,
            :stall_rating,
            :food_court_rating,
            inclusion: { in: 1..5 }

  validates :expectations,
            inclusion: {
              in: %w[yes partially no]
            }
end
class LuckyDrawResult < ApplicationRecord
  belongs_to :event
  belongs_to :visitor
  belongs_to :drawn_by, polymorphic: true, optional: true

  validates :event_id,   presence: true
  validates :visitor_id, presence: true
  validates :round,      presence: true

  scope :for_event, ->(event_id) { where(event_id: event_id).order(round: :asc) }

  # Auto-assign round number before create
  before_create :assign_round

  private

  def assign_round
    last = LuckyDrawResult.where(event_id: event_id).maximum(:round) || 0
    self.round = last + 1
  end
end

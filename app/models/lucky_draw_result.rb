class LuckyDrawResult < ApplicationRecord
  belongs_to :event
  belongs_to :visitor
  belongs_to :drawn_by, polymorphic: true, optional: true

  DRAW_TYPES = %w[regular bumper].freeze

  validates :event_id,   presence: true
  validates :visitor_id, presence: true
  validates :round,      presence: true
  validates :draw_type,  inclusion: { in: DRAW_TYPES }

  scope :for_event,   ->(event_id) { where(event_id: event_id).order(round: :asc) }
  scope :regular,     -> { where(draw_type: "regular") }
  scope :bumper,      -> { where(draw_type: "bumper") }

  before_create :assign_round

  private

  def assign_round
    last = LuckyDrawResult.where(event_id: event_id, draw_type: draw_type).maximum(:round) || 0
    self.round = last + 1
  end
end


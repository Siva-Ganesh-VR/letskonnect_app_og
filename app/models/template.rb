class Template < ApplicationRecord
  TYPES = %w[question message].freeze

  has_many :template_questions
  has_many :template_messages
  has_many :events

  validates :name, presence: true
  validates :template_type, inclusion: { in: TYPES }

  scope :question_templates, -> {
    where(
      template_type: "question",
      active: true
    )
  }
  scope :message_templates, -> {
    where(
      template_type: "message",
      active: true
    )
  }
  def self.default_question_template
    find_by(
      template_type: "question",
      active: true,
      is_default: true
    )
  end

  def self.default_message_template
    find_by(
      template_type: "message",
      active: true,
      is_default: true
    )
  end

end
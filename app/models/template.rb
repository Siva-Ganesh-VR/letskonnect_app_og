class Template < ApplicationRecord
  TYPES = %w[question message].freeze

  has_many :template_questions
  has_many :template_messages

  validates :name, presence: true
  validates :template_type, inclusion: { in: TYPES }

end
class TemplateQuestion < ApplicationRecord
  belongs_to :template

  FIELD_TYPES = %w[
    text
    textarea
    number
    email
    mobile
    date
    select
    radio
    checkbox
  ].freeze

  validates :question, presence: true
  validates :field_type, presence: true, inclusion: { in: FIELD_TYPES }
  validates :display_order, presence: true, numericality: { greater_than: 0 }

  validate :options_required_for_choice_fields

  private

  def options_required_for_choice_fields
    return unless %w[select radio checkbox].include?(field_type)

    if options.blank?
      errors.add(:options, "can't be blank")
    end
  end
end
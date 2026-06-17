class ExportJob < ApplicationRecord
  belongs_to :exportable, polymorphic: true

  TYPES    = %w[leads_excel visitors_excel visitors_pdf event_report].freeze
  STATUSES = %w[pending processing completed failed].freeze

  validates :export_type, inclusion: { in: TYPES }
  validates :status,      inclusion: { in: STATUSES }

  scope :expired,   -> { where("expires_at < ?", Time.current) }
  scope :completed, -> { where(status: "completed") }
end

# app/models/error_log.rb
class ErrorLog < ApplicationRecord
  SOURCES    = %w[api sidekiq frontend ocr].freeze
  SEVERITIES = %w[error warning info].freeze

  validates :source,   inclusion: { in: SOURCES }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :message,  presence: true

  scope :unresolved,  -> { where(resolved: false) }
  scope :errors_only, -> { where(severity: "error") }
  scope :recent,      -> { order(created_at: :desc) }
  scope :for_event,   ->(id) { where(event_id: id) }
  scope :by_source,   ->(s)  { where(source: s) }

  # ── Main log method — use this everywhere ─────────────────────
  def self.capture(message:, source:, severity: "error", **attrs)
    create!(
      message:  message.to_s.truncate(2000),
      source:   source,
      severity: severity,
      **attrs.slice(
        :error_type, :status_code, :backtrace, :context,
        :endpoint, :http_method, :request_params,
        :job_class, :job_id,
        :event_id, :visitor_id, :stall_owner_id, :organizer_id, :user_type,
        :ip_address, :user_agent, :request_id
      )
    )
  rescue => e
    # Never let error logging crash the app
    Rails.logger.error("[ErrorLog] Failed to save error log: #{e.message}")
    nil
  end

  def context_parsed
    JSON.parse(context) rescue {}
  end

  def request_params_parsed
    JSON.parse(request_params) rescue {}
  end
end

# app/jobs/concerns/error_logging_job.rb
#
# Include in ApplicationJob to auto-capture Sidekiq failures
#
# Usage:
#   class ApplicationJob < ActiveJob::Base
#     include ErrorLoggingJob
#   end
#
module ErrorLoggingJob
  extend ActiveSupport::Concern

  included do
    rescue_from(StandardError) do |exception|
      # Log to ErrorLog table
      ErrorLog.capture(
        message:    exception.message.truncate(2000),
        source:     "sidekiq",
        severity:   "error",
        error_type: exception.class.name,
        backtrace:  exception.backtrace&.first(20)&.join("\n"),
        job_class:  self.class.name,
        job_id:     job_id,
        context:    { arguments: arguments.map(&:to_s) }.to_json,
      )

      Rails.logger.error("[Job Error] #{self.class.name} ##{job_id}: #{exception.message}")

      # Re-raise so Sidekiq retries the job normally
      raise
    end
  end
end

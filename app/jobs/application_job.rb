class ApplicationJob < ActiveJob::Base
  include ErrorLoggingJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError
end

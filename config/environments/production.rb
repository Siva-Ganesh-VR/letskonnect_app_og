require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true

  config.log_level = :info
  config.log_tags = [:request_id]

  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL"),
    connect_timeout: 30,
    read_timeout: 0.2,
    write_timeout: 0.2,
    reconnect_attempts: 1,
    error_handler: ->(method:, returning:, exception:) {
      Rails.logger.error("Redis error: #{exception.class} #{exception.message}")
    }
  }

  config.active_storage.service = :amazon
  config.active_record.dump_schema_after_migration = false

  config.log_formatter = ::Logger::Formatter.new
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
  config.hosts << "letskonnect-app-og.onrender.com"
end

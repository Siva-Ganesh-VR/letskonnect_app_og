class HealthController < ApplicationController
  def index
    checks = {
      database: database_ok?,
      redis:    redis_ok?,
      sidekiq:  sidekiq_ok?
    }
    status = checks.values.all? ? :ok : :service_unavailable
    render json: { status: status == :ok ? "healthy" : "degraded", checks: checks }, status: status
  end

  private

  def database_ok?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue => e
    Rails.logger.error("DB health check failed: #{e.message}")
    false
  end

  def redis_ok?
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping == "PONG"
  rescue => e
    false
  end

  def sidekiq_ok?
    Sidekiq::Stats.new.processed >= 0
  rescue => e
    false
  end
end

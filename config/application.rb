require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module Letskonnect
  class Application < Rails::Application
    config.load_defaults 7.2

    # Not purely API — we have some HTML pages (registration, visitor pass, admin)
    # config.api_only = true  # DISABLED — we need ActionController::Base for views

    config.time_zone = "Chennai"
    config.active_record.default_timezone = :utc

    config.action_cable.mount_path = "/cable"
    config.action_cable.allowed_request_origins = [/http:\/\/localhost.*/, /https?:\/\/letskonnect.*/]

    config.active_storage.service = Rails.env.production? ? :amazon : :local
    config.active_job.queue_adapter = :sidekiq

    # Serve static files from public/
    config.public_file_server.enabled = true

    config.middleware.use Rack::Attack
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "*", headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ["Authorization"]
      end
    end

    config.generators do |g|
      g.test_framework :rspec
      g.factory_bot true
    end
  end
end

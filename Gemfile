source "https://rubygems.org"
ruby "3.2.2"

# Core
gem "rails",     "~> 7.2.0"
gem "pg",        "~> 1.5"
gem "puma",      "~> 6.4"
gem "bootsnap",  require: false

# Auth
gem "devise"
gem "jwt",       "~> 2.7"
gem "bcrypt",    "~> 3.1.7"

# Background Jobs
gem "sidekiq",           "~> 7.2"
gem "sidekiq-scheduler", "~> 5.0"

# Redis
gem "redis", "~> 5.0"
gem "connection_pool", "~> 2.4"

# QR Code
gem "rqrcode",    "~> 2.1"
gem "chunky_png", "~> 1.4"

# WhatsApp / SMS
gem "twilio-ruby", "~> 7.0"
gem "faraday",     "~> 2.9"
# gem "faraday-json"

# Excel export
gem "caxlsx",      "~> 3.3"
gem "caxlsx_rails"

# PDF export
gem "prawn",       "~> 2.5"
gem "prawn-table", "~> 0.2"

# Rate Limiting
gem "rack-attack", "~> 6.7"

# Pagination
gem "pagy", "~> 8.0"

# Storage
gem "aws-sdk-s3",      require: false
gem "image_processing", "~> 1.2"
gem "ruby-vips",        require: false

# Phone validation
gem "phonelib"

# Search
gem "pg_search"

# CORS
gem "rack-cors"

# JSON
gem "oj", "~> 3.16"

# Environment
gem "dotenv-rails"

group :development, :test do
  gem "rspec-rails",        "~> 6.1"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "shoulda-matchers",   "~> 6.0"
end

group :development do
  gem "annotate"
  gem "letter_opener"
end

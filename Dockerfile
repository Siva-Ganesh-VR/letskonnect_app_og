FROM ruby:3.2.2-slim

# System dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  libvips \
  git \
  curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# App code
COPY . .

# Precompile bootsnap
RUN bundle exec bootsnap precompile --gemfile app/ lib/

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

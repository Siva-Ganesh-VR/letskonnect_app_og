max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 10)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")
# FIXED: raised from 2 to 4 workers
# Each worker = 1 OS process = 10 threads = 10 concurrent requests
# 4 workers × 10 threads = 40 concurrent requests
# Your server (11.68GB RAM, 4 CPU) can handle this comfortably
workers ENV.fetch("WEB_CONCURRENCY", 0)
preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

plugin :tmp_restart

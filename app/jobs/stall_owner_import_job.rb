class StallOwnerImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, event_id, progress_id)
    require "csv"

    redis = REDIS
    key = "import_progress:#{progress_id}"

    rows = CSV.read(
      file_path,
      headers: true,
      encoding: "bom|utf-8"
    )

    redis.hset(
      key,
      "status", "processing",
      "total", rows.size,
      "processed", 0,
      "success", 0,
      "failed", 0
    )
    redis.expire(key, 1.hour.to_i)

    event = Event.find(event_id)
    organizer = event.event_organizer

    mobile_numbers = rows.map { |r| r["mobile_number"]&.strip }.compact

    existing_stall_owners = StallOwner
      .where(mobile_number: mobile_numbers)
      .index_by(&:mobile_number)

    success = 0
    failed = 0
    errors = []

    rows.each_with_index do |row, index|
      generated_password = SecureRandom.alphanumeric(8)

      stall = StallOwner.new(
        name: row["name"]&.strip,
        mobile_number: row["mobile_number"]&.strip,
        company_name: row["company_name"]&.strip,
        stall_number: row["stall_number"]&.strip,
        stall_category: row["stall_category"]&.strip,
        stall_type: row["stall_type"]&.strip,
        stall_size: row["stall_size"]&.strip,
        price: row["price"]&.strip,
        email: row["email"]&.strip,
        password: generated_password,
        password_confirmation: generated_password,
        event_id: event_id
      )

      stall.event_organizer = organizer

      if (existing = existing_stall_owners[stall.mobile_number])
        stall.pass_code = existing.pass_code
      else
        stall.pass_code = rand(100000..999999).to_s
      end

      if stall.save
        success += 1

        # WhatsappNotificationJob.perform_later(...)
      else
        failed += 1

        errors << {
          line: index + 2,
          errors: stall.errors.full_messages
        }
      end

      processed = index + 1

      if processed % 5 == 0 || processed == rows.size
        redis.hset(
          key,
          "processed", processed,
          "success", success,
          "failed", failed
        )

        redis.expire(key, 1.hour.to_i)
      end
    end

    redis.hset(
      key,
      "status", "completed",
      "processed", rows.size,
      "success", success,
      "failed", failed
    )

    Rails.logger.info(
      "Stall import completed. Success: #{success}, Failed: #{failed}"
    )

  rescue => e
    redis&.hset(
      key,
      "status", "failed",
      "message", e.message
    )

    Rails.logger.error(e.full_message)
    raise

  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
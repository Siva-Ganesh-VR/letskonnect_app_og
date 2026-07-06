class StallOwnerImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, event_id)
    require "csv"

    event = Event.find(event_id)
    organizer = event.event_organizer

    rows = CSV.read(
      file_path,
      headers: true,
      encoding: "bom|utf-8"
    )

    mobile_numbers = rows.map { |row| row["mobile_number"]&.strip }.compact

    existing_stall_owners = StallOwner
      .where(mobile_number: mobile_numbers)
      .index_by(&:mobile_number)

    created = []
    errors = []

    rows.each_with_index do |row, index|
      line_no = index + 2
      generated_password = SecureRandom.alphanumeric(8)

      stall = StallOwner.new(
        name: row["name"]&.strip,
        mobile_number: row["mobile_number"]&.strip,
        company_name: row["company_name"]&.strip,
        stall_number: row["stall_number"]&.strip,
        stall_category: row["stall_category"]&.strip,
        email: row["email"]&.strip,
        password: generated_password,
        password_confirmation: generated_password,
        event_id: event_id
      )

      stall.event_organizer = organizer
      stall.pass_code = rand(100000..999999).to_s

      if (existing = existing_stall_owners[stall.mobile_number])
        stall.pass_code = existing.pass_code
      end

      if stall.save
        created << stall.id

        # WhatsappNotificationJob.perform_later(
        #   stall.id,
        #   "stall_credentials",
        #   generated_password
        # )
      else
        errors << {
          line: line_no,
          errors: stall.errors.full_messages
        }
      end
    end

    Rails.logger.info(
      "Stall import completed. Created: #{created.size}, Failed: #{errors.size}"
    )
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
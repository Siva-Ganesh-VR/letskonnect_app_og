class StallOwnerImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, event_id)
    require "csv"

    event = Event.find(event_id)
    organizer = event.event_organizer

    created = []
    errors = []

    CSV.foreach(
      file_path,
      headers: true,
      encoding: "bom|utf-8"
    ).with_index(2) do |row, line_no|

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

    File.delete(file_path) if File.exist?(file_path)
  end
end
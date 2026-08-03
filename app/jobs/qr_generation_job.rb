class QrGenerationJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5

  def perform(record_id, record_type)
    case record_type
    when "visitor"
      visitor = Visitor.find(record_id)

      return if visitor.registration_qr.attached?

      QrService.generate_for_visitor(visitor)
      if visitor.send_registration_whatsapp? && visitor.qr_image_url.present?
        WhatsappNotificationJob.perform_later(visitor.id, "visitor_registration")
        visitor.update_column(:send_registration_whatsapp, false)
      end

      Rails.logger.info("[QR] Generated for visitor #{visitor.visitor_id_code}")

    when "event"
      event = Event.find(record_id)

      return if event.registration_qr.attached?

      QrService.generate_for_event(event)
      Rails.logger.info("[QR] Generated for event #{event.name}")
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[QR Job] Record not found: #{e.message}")
  end
end
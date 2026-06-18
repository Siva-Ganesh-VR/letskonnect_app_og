class WhatsappNotificationJob < ApplicationJob
  queue_as :whatsapp
  sidekiq_options retry: 3

  def perform(record_id, notification_type, extra_id = nil)
    Rails.logger.info("[WhatsApp Job] #{notification_type} for #{record_id}")

    result = case notification_type
    when "visitor_registration"
      visitor = Visitor.includes(:event).find(record_id)
      WhatsappService.send_registration_confirmation(visitor)

    when "stall_visit"
      visitor     = Visitor.find(record_id)
      stall_owner = StallOwner.find(extra_id)
      WhatsappService.send_stall_visit(visitor, stall_owner)

    when "stall_credentials"
      stall_owner = StallOwner.includes(:event).find(record_id)
      password    = extra_id  # passed as password string
      WhatsappService.send_stall_credentials(stall_owner, password)

    when "export_ready"
      export_job  = ExportJob.find(record_id)
      stall_owner = export_job.exportable
      WhatsappService.send_export_ready(stall_owner, export_job.file_url)

    else
      Rails.logger.warn("[WhatsApp Job] Unknown notification type: #{notification_type}")
      return
    end

    notifiable = find_notifiable(notification_type, record_id, extra_id)

    # Log notification
    Notification.create!(
      notifiable:        notifiable,
      notification_type: notification_type,
      channel:           "whatsapp",
      status:            result[:success] ? "sent" : "failed",
      external_message_id: result[:sid],
      error_message:     result[:error],
      sent_at:           result[:success] ? Time.current : nil,
      payload:           { type: notification_type }
    )
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[WhatsApp Job] Record not found: #{e.message}")
  end

  private

  def find_notifiable(type, record_id, extra_id)
    case type
    when "visitor_registration", "stall_visit"
      Visitor.find_by(id: record_id)

    when "stall_credentials"
      StallOwner.find_by(id: record_id)

    when "export_ready"
      ExportJob.find_by(id: record_id)&.exportable

    else
      Rails.logger.error("[WhatsApp Job] Unsupported notification type: #{type}")
      nil
    end
  end
end

class WhatsappService
  INDIA_PREFIX = "+91"

  def self.send_registration_confirmation(visitor)
    message = <<~MSG
      🎉 *Welcome to #{visitor.event.name}!*

      Hi #{visitor.full_name},
      Your registration is confirmed! ✅

      🪪 *Visitor ID:* #{visitor.visitor_id_code}
      📍 *Venue:* #{visitor.event.venue}#{visitor.event.city.present? ? ", #{visitor.event.city}" : ""}
      📅 *Date:* #{visitor.event.start_date.strftime("%B %d")} – #{visitor.event.end_date.strftime("%B %d, %Y")}

      🔗 Your QR Code: #{visitor.display_qr_url}

      _Show this QR at any exhibitor stall to instantly share your details._

      Powered by *StallConnect* 🤝
    MSG
    send_message(visitor.mobile_number, message, visitor.qr_image_url)
  end

  def self.send_stall_visit(visitor, stall_owner)
    message = <<~MSG
      👋 Hi #{visitor.full_name},

      Thank you for visiting *#{stall_owner.company_name}*#{stall_owner.stall_number.present? ? " (Stall #{stall_owner.stall_number})" : ""}!

      Our team will reach out to you soon. 🙏

      Powered by *StallConnect* 🤝
    MSG
    send_message(visitor.mobile_number, message)
  end

  def self.send_followup(visitor, stall_owner, custom_message = nil)
    body = custom_message.presence || "We appreciate your interest. Our team will connect with you shortly."
    message = <<~MSG
      Hi #{visitor.full_name},

      *#{stall_owner.company_name}* has a message for you:

      #{body}

      Powered by *StallConnect* 🤝
    MSG
    send_message(visitor.mobile_number, message)
  end

  def self.send_stall_credentials(stall_owner, password)
    message = <<~MSG
      🏪 *StallConnect — Exhibitor Login*

      Hi #{stall_owner.name},

      Your exhibitor account for *#{stall_owner.event.name}* is ready!

      📱 *Mobile:* #{stall_owner.mobile_number}
      🔐 *Password:* #{password}
      🏪 *Stall:* #{stall_owner.stall_number || "N/A"} — #{stall_owner.company_name}

      Login to the StallConnect app and scan visitor QR codes to capture leads instantly.

      Powered by *StallConnect* 🤝
    MSG
    send_message(stall_owner.mobile_number, message)
  end

  def self.send_export_ready(stall_owner, file_url)
    message = <<~MSG
      📊 *Your Lead Export is Ready!*

      Hi #{stall_owner.name},

      Download your leads file here:
      👉 #{file_url}

      _(Link valid for 24 hours)_

      Powered by *StallConnect* 🤝
    MSG
    send_message(stall_owner.mobile_number, message)
  end

  def self.send_daily_summary(stall_owner, summary)
    message = <<~MSG
      📊 *Daily Lead Summary*

      Hi #{stall_owner.name} (#{stall_owner.company_name}),

      Here's your performance for today:

      🔥 Hot Leads: #{summary[:hot]}
      ♨️  Warm Leads: #{summary[:warm]}
      🆕 New Today: #{summary[:today]}
      ✅ Converted: #{summary[:converted]}
      📅 Follow-ups due: #{summary[:follow_up_today]}

      *Total All-Time: #{summary[:total]}*

      Login to the app to follow up on your hot leads!

      Powered by *StallConnect* 🤝
    MSG
    send_message(stall_owner.mobile_number, message)
  end

  def self.send_message(mobile_number, body, media_url = nil)
    # return mock_send(mobile_number, body) if Rails.env.development? || Rails.env.test?

    client = Twilio::REST::Client.new(
      ENV.fetch("TWILIO_ACCOUNT_SID"),
      ENV.fetch("TWILIO_AUTH_TOKEN")
    )

    params = {
      from: ENV.fetch("TWILIO_WHATSAPP_FROM", "whatsapp:+14155238886"),
      to: "whatsapp:#{INDIA_PREFIX}#{mobile_number}",
      body: body
    }
    params[:media_url] = [media_url] if media_url.present?
    response = client.messages.create(**params)

    { success: true, sid: response.sid }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[WhatsApp] Error for #{mobile_number}: #{e.message}")
    { success: false, error: e.message }
  rescue => e
    Rails.logger.error("[WhatsApp] Unexpected error: #{e.message}")
    { success: false, error: e.message }
  end

  def self.mock_send(mobile, body)
    Rails.logger.info("[WhatsApp MOCK] To: #{mobile}\n#{body}")
    { success: true, mock: true }
  end

  def self.send_template(mobile_number, template_sid, variables = nil)
    client = Twilio::REST::Client.new(
      ENV.fetch("TWILIO_ACCOUNT_SID"),
      ENV.fetch("TWILIO_AUTH_TOKEN")
    )

    payload = {
      from: ENV.fetch("TWILIO_WHATSAPP_FROM"),
      to: "whatsapp:+91#{mobile_number}",
      content_sid: template_sid
    }

    payload[:content_variables] = variables.to_json if variables.present?

    response = client.messages.create(**payload)

    { success: true, sid: response.sid }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[WhatsApp] Error: #{e.message}")
    { success: false, error: e.message }
  end
end

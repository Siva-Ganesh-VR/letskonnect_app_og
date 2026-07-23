class SmsService
  def self.send_otp(mobile_number, otp)
    message = "#{otp} is your OTP for StallConnect event registration. Valid for 10 minutes. Do not share with anyone."

    return mock_send(mobile_number, otp) if Rails.env.development? || Rails.env.test?

    conn = Faraday.new(url: "https://www.fast2sms.com") do |f|
      f.headers["authorization"] = ENV.fetch("FAST2SMS_API_KEY")
      f.request  :json
      f.response :json
    end

    response = conn.post("/dev/bulkV2") do |req|
      req.body = {
        route:            "otp",
        variables_values: otp.to_s,
        numbers:          mobile_number.to_s,
        flash:            0
      }
    end

    if response.body["return"]
      { success: true }
    else
      Rails.logger.error("[SMS] Failed for #{mobile_number}: #{response.body}")
      { success: false, error: response.body.to_s }
    end
  rescue => e
    Rails.logger.error("[SMS] Error: #{e.message}")
    { success: false, error: e.message }
  end

  def self.mock_send(mobile, otp)
    Rails.logger.info("🔐 [SMS MOCK] OTP for #{mobile}: #{otp}")
    { success: true, mock: true, otp: otp }
  end
end

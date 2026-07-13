class Rack::Attack
  safelist("load-test-ip") do |req|
    req.ip == "123.176.34.73"   # ← replace with your actual IP
  end
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  )

  # OTP request rate: 5 per mobile per hour
  throttle("otp/mobile", limit: 5, period: 1.hour) do |req|
    if (req.path.include?("request_otp") || req.path.include?("register")) && req.post?
      mobile = req.params["mobile_number"]&.gsub(/\D/, "")
      mobile if mobile&.length == 10
    end
  end

  # OTP verify attempts: 10 per IP per 10 minutes
  throttle("otp_verify/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if req.path.include?("verify_otp") && req.post?
  end

  # Visitor registration: 5 per IP per minute
  throttle("registrations/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.include?("visitors/register") && req.post?
  end

  # QR scan: 120 per auth token per minute (2 scans/sec max)
  throttle("qr_scan/auth", limit: 120, period: 1.minute) do |req|
    if req.path.include?("scan") && req.post?
      req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last&.first(32)
    end
  end

  # General API: 300 requests per minute per IP
  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Login brute force: 10 per IP per 10 minutes
  throttle("logins/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if req.path.include?("sign_in") && req.post?
  end

  # Block known bad IPs (admin-managed via Redis)
  blocklist("blocked_ips") do |req|
    Rack::Attack.cache.read("blocked_ip:#{req.ip}")
  end

  # Safelist health check
  safelist("health_check") do |req|
    req.path == "/health"
  end

  # Custom throttle response
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After"  => retry_after.to_s
      },
      [{
        success: false,
        error: "Rate limit exceeded. Please wait before trying again.",
        retry_after_seconds: retry_after
      }.to_json]
    ]
  end
end

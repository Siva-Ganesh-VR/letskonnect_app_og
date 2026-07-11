class QrService
  QR_SIZE = 400

  def self.generate_for_visitor(visitor)
    generate_and_store(visitor.display_qr_url, "visitors/#{visitor.id}/qr_code.png")
  end

  def self.generate_for_event(event)
    generate_and_store(event.registration_url, "events/#{event.id}/registration_qr.png")
  end

  def self.generate_base64(url)
    png = build_png(url)
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end

  private

  def self.build_png(url)
    RQRCode::QRCode.new(url, level: :m).as_png(
      size: QR_SIZE,
      border_modules: 4,
      color: "black",
      fill: "white"
    )
  end

  def self.generate_and_store(url, path)
    png = build_png(url)

    Tempfile.create(["qr_code", ".png"]) do |source|
      source.binmode
      source.write(png.to_s)
      source.rewind

      Tempfile.create(["qr_code_24", ".png"]) do |converted|
        converted.close

        system(
          "convert",
          source.path,
          "-define", "png:color-type=2",
          "PNG24:#{converted.path}"
        ) or raise "Failed to convert QR image to PNG24"

        File.open(converted.path, "rb") do |file|
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: File.basename(path),
            content_type: "image/png",
            key: path
          )

          return Rails.application.routes.url_helpers.rails_storage_proxy_url(
            blob,
            host: ENV.fetch("APP_HOST", "http://localhost:3000")
          )
        end
      end
    end
  end
end
class QrService
  QR_SIZE = 200

  def self.generate_for_visitor(visitor)
    url = visitor.display_qr_url
    generate_and_store(url, "visitors/#{visitor.id}/qr_code.png")
  end

  def self.generate_for_event(event)
    url = event.registration_url
    generate_and_store(url, "events/#{event.id}/registration_qr.png")
  end

  def self.generate_base64(url)
    png = build_png(url)
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end

  private

  def self.build_png(url)
    qr = RQRCode::QRCode.new(url, level: :m)
    qr.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      fill: "white",
      module_px_size: 6,
      size: QR_SIZE
    )
  end

  def self.generate_and_store(url, path)
    png = build_png(url)

    Tempfile.create(["qr_code", ".png"]) do |file|
      file.binmode
      file.write(png.to_s)
      file.rewind

      blob = ActiveStorage::Blob.create_and_upload!(
        io:           file,
        filename:     File.basename(path),
        content_type: "image/png",
        key:          path
      )

      Rails.application.routes.url_helpers.rails_blob_url(
        blob,
        host: ENV.fetch("APP_HOST", "http://localhost:3000")
      )
    end
  end
end

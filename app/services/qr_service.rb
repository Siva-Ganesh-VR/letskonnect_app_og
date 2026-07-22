class QrService
  QR_SIZE = 400

  def self.generate_for_visitor(visitor)
    attach_qr(
      record: visitor,
      attachment_name: :registration_qr,
      url: visitor.display_qr_url,
      filename: "qr_code.png",
      key: "visitors/#{visitor.id}/qr_code.png"
    )
  end

  def self.generate_for_event(event)
    attach_qr(
      record: event,
      attachment_name: :registration_qr,
      url: event.registration_url,
      filename: "registration_qr.png",
      key: "events/#{event.id}/registration_qr.png"
    )
  end

  def self.generate_base64(url)
    png = build_png(url)
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end

  private

  def self.build_png(url)
    # Use explicit hex color values to avoid any ambiguity in color names
    RQRCode::QRCode.new(url, level: :m).as_png(
      size: QR_SIZE,
      border_modules: 4,
      color: "#000000",
      fill: "#ffffff"
    )
  end

  def self.attach_qr(record:, attachment_name:, url:, filename:, key:)
    attachment = record.public_send(attachment_name)

    # Already attached
    return record if attachment.attached?

    # Blob already exists (from previous implementation)
    if (blob = ActiveStorage::Blob.find_by(key: key))
      attachment.attach(blob)
      return record
    end

    # Generate and upload only if blob doesn't exist
    png = build_png(url)

    Tempfile.create(["qr_code", ".png"]) do |source|
      source.binmode
      source.write(png.to_s)
      source.rewind

      Tempfile.create(["qr_code_png24", ".png"]) do |converted|
        converted.close

        system(
          "convert",
          source.path,
          "-define", "png:color-type=2",
          "PNG24:#{converted.path}"
        ) or raise "Failed to convert QR image to PNG24"

        File.open(converted.path, "rb") do |file|
          attachment.attach(
            io: file,
            filename: filename,
            content_type: "image/png",
            key: key
          )
        end
      end
    end

    record
  end
end

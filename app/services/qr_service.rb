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

  # Pure Ruby PNG generation — no ImageMagick required.
  # Uses rqrcode + chunky_png (both already in Gemfile).
  def self.build_png(url)
    qr = RQRCode::QRCode.new(url, level: :m)

    qr.as_png(
      size:           QR_SIZE,
      border_modules: 4,
      color:          "black",
      fill:           "white"
    )
  end

  def self.attach_qr(record:, attachment_name:, url:, filename:, key:)
    attachment = record.public_send(attachment_name)

    # Already attached — nothing to do
    return record if attachment.attached?

    # Blob already exists in storage (from a previous run)
    if (blob = ActiveStorage::Blob.find_by(key: key))
      attachment.attach(blob)
      return record
    end

    # Generate PNG purely in Ruby — no ImageMagick
    png = build_png(url)
    png_bytes = png.to_s  # chunky_png .to_s returns binary PNG data

    # Write to a single temp file and attach directly
    Tempfile.create(["qr_code", ".png"], binmode: true) do |f|
      f.write(png_bytes)
      f.rewind

      attachment.attach(
        io:           f,
        filename:     filename,
        content_type: "image/png",
        key:          key
      )
    end

    record
  end
end

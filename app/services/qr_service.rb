require 'rqrcode'
require 'chunky_png'

class QrService
  QR_SIZE = 400

  def self.generate_for_visitor(visitor)
    attach_qr(
      record:          visitor,
      attachment_name: :registration_qr,
      url:             visitor.display_qr_url,
      filename:        "qr_code.png",
      key:             "visitors/#{visitor.id}/qr_code.png"
    )
  end

  def self.generate_for_event(event)
    attach_qr(
      record:          event,
      attachment_name: :registration_qr,
      url:             event.registration_url,
      filename:        "registration_qr.png",
      key:             "events/#{event.id}/registration_qr.png"
    )
  end

  def self.generate_bni_for_event(event)
    attach_qr(
      record:          event,
      attachment_name: :bni_registration_qr,
      url:             event.bni_registration_url,
      filename:        "bni_registration_qr.png",
      key:             "events/#{event.id}/bni_registration_qr.png"
    )
  end

  def self.generate_base64(url)
    png = build_png(url)
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end

  private

  def self.build_png(url)
    RQRCode::QRCode.new(url, level: :m).as_png(
      size:           QR_SIZE,
      border_modules: 4,
      color:          "black",
      fill:           "white"
    )
  end

  def self.attach_qr(record:, attachment_name:, url:, filename:, key:)
    attachment = record.public_send(attachment_name)

    # Already attached
    return record if attachment.attached?

    # Blob already exists
    if (blob = ActiveStorage::Blob.find_by(key: key))
      attachment.attach(blob)
      return record
    end

    # Generate PNG — pure Ruby, no ImageMagick needed
    png = build_png(url)

    Tempfile.create(["qr_code", ".png"]) do |tmp|
      tmp.binmode
      tmp.write(png.to_s)
      tmp.rewind

      attachment.attach(
        io:           tmp,
        filename:     filename,
        content_type: "image/png",
        key:          key
      )
    end

    record
  end
end

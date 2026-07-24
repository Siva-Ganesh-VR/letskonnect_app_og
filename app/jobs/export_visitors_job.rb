class ExportVisitorsJob < ApplicationJob
  queue_as :exports
  sidekiq_options retry: 2

  def perform(export_job_id)
    job   = ExportJob.find(export_job_id)
    event = job.exportable
    job.update!(status: "processing")

    visitors = event.visitors.verified.order(created_at: :asc)

    if job.export_type == "visitors_excel"
      export_excel(job, event, visitors)
    else
      export_pdf(job, event, visitors)
    end
  rescue => e
    job.update!(status: "failed", error_message: e.message)
    Rails.logger.error("[ExportVisitors] #{e.message}")
    raise
  end

  private

  def export_excel(job, event, visitors)
    package  = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Visitors") do |sheet|
      header = ["#", "Visitor ID", "Name", "Mobile", "Email",
                 "Business Name", "Category", "Profession", "Location",
                 "Designation", "Website", "Registered At"]
      sheet.add_row(header)

      visitors.each_with_index do |v, i|
        sheet.add_row([
          i + 1, v.visitor_id_code, v.full_name, v.mobile_number, v.email,
          v.business_name, v.business_category, v.profession, v.location,
          v.designation, v.website, v.created_at.strftime("%d %b %Y %H:%M")
        ])
      end
      sheet.column_widths 4, 16, 25, 14, 28, 28, 20, 18, 15, 15, 28, 18
    end

    filename = "visitors_#{event.name.parameterize}_#{Date.today}.xlsx"
    Tempfile.create([filename, ".xlsx"]) do |f|
      package.serialize(f.path)
      f.rewind
      blob = ActiveStorage::Blob.create_and_upload!(
        io: f, filename: filename,
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      )
      url = Rails.application.routes.url_helpers.rails_blob_url(
        blob, host: ENV.fetch("APP_HOST", "http://localhost:3000")
      )
      job.update!(status: "completed", file_url: url, completed_at: Time.current)
    end

    WhatsappNotificationJob.perform_later(job.id, "visitor_export_ready")
  end

  def export_pdf(job, event, visitors)
    pdf = Prawn::Document.new(page_size: "A4", margin: [30, 30, 40, 30])

    pdf.font_size 10
    pdf.text event.name, size: 18, style: :bold, color: "1a1a2e"
    pdf.text "Visitor Report — #{Date.today.strftime("%B %d, %Y")}", size: 10, color: "666666"
    pdf.text "Total Visitors: #{visitors.count}", size: 10, style: :bold
    pdf.move_down 10

    data = [["#", "Name", "Mobile", "Business", "Category", "Registered"]] +
      visitors.each_with_index.map do |v, i|
        [i+1, v.full_name.truncate(22), v.mobile_number,
         v.business_name&.truncate(20), v.business_category&.truncate(16),
         v.created_at.strftime("%d/%m/%Y")]
      end

    pdf.table(
      data,
      header: true,
      width:  pdf.bounds.width,
      row_colors: ["FFFFFF", "F5F5F5"],
      cell_style: { size: 8, padding: [4, 6], border_color: "E0E0E0" },
      header: true
    ) do
      row(0).style(background_color: "1a1a2e", text_color: "FFFFFF", font_style: :bold)
    end

    pdf.number_pages "<page> of <total>", at: [pdf.bounds.right - 80, -20], size: 8

    filename = "visitors_#{event.name.parameterize}_#{Date.today}.pdf"
    Tempfile.create([filename, ".pdf"]) do |f|
      pdf.render_file(f.path)
      f.rewind
      blob = ActiveStorage::Blob.create_and_upload!(
        io: f, filename: filename, content_type: "application/pdf"
      )
      url = Rails.application.routes.url_helpers.rails_blob_url(
        blob, host: ENV.fetch("APP_HOST", "http://localhost:3000")
      )
      job.update!(status: "completed", file_url: url, completed_at: Time.current)
    end

    WhatsappNotificationJob.perform_later(job.id, "visitor_export_ready")
  end
end

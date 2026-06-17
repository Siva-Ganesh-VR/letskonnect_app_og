class ExportLeadsJob < ApplicationJob
  queue_as :exports
  sidekiq_options retry: 2

  def perform(export_job_id)
    job = ExportJob.find(export_job_id)
    job.update!(status: "processing")

    stall_owner = job.exportable
    leads = filter_leads(stall_owner, job.filters)

    package  = Axlsx::Package.new
    workbook = package.workbook

    workbook.styles do |s|
      header_style = s.add_style(
        bg_color: "1a1a2e", fg_color: "FFFFFF",
        b: true, sz: 11, alignment: { horizontal: :center }
      )
      hot_style   = s.add_style(bg_color: "FFEBE6")
      warm_style  = s.add_style(bg_color: "FFF9E6")
      cold_style  = s.add_style(bg_color: "E6F4FF")
      normal_even = s.add_style(bg_color: "F9F9F9")
      normal_odd  = s.add_style(bg_color: "FFFFFF")

      workbook.add_worksheet(name: "Leads") do |sheet|
        sheet.add_row(
          ["#", "Name", "Mobile", "Email", "Business Name", "Category",
           "Profession", "Location", "Designation", "Temperature", "Status",
           "Rating", "Notes", "Requirements", "Budget", "Follow-up Date",
           "Remarks", "Scanned At"],
          style: header_style
        )

        leads.each_with_index do |lead, idx|
          v     = lead.visitor
          style = case lead.temperature
                  when "hot"  then hot_style
                  when "warm" then warm_style
                  when "cold" then cold_style
                  else idx.even? ? normal_even : normal_odd
                  end

          sheet.add_row([
            idx + 1,
            v.full_name,
            v.mobile_number,
            v.email,
            v.business_name,
            v.business_category,
            v.profession,
            v.location,
            v.designation,
            lead.temperature.upcase,
            lead.status.titleize,
            "#{lead.interest_rating}/5",
            lead.notes,
            lead.requirements,
            lead.budget ? "₹#{lead.budget}" : "",
            lead.follow_up_date,
            lead.remarks,
            lead.scanned_at.strftime("%d %b %Y %H:%M")
          ], style: style)
        end

        sheet.column_widths 4, 25, 14, 25, 25, 18, 15, 15, 15, 10, 12, 7, 30, 20, 12, 14, 30, 18
      end

      # Summary sheet
      workbook.add_worksheet(name: "Summary") do |sheet|
        sheet.add_row(["Metric", "Count"], style: header_style)
        sheet.add_row(["Total Leads",      leads.count])
        sheet.add_row(["Hot Leads",        leads.count { |l| l.temperature == "hot" }])
        sheet.add_row(["Warm Leads",       leads.count { |l| l.temperature == "warm" }])
        sheet.add_row(["Cold Leads",       leads.count { |l| l.temperature == "cold" }])
        sheet.add_row(["Converted",        leads.count { |l| l.status == "converted" }])
        sheet.add_row(["Exported On",      Time.current.strftime("%d %b %Y %H:%M")])
        sheet.add_row(["Stall",            "#{stall_owner.company_name} (#{stall_owner.stall_number})"])
      end
    end

    filename = "leads_#{stall_owner.company_name.parameterize}_#{Date.today}.xlsx"
    content_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    Tempfile.create([filename, ".xlsx"]) do |f|
      package.serialize(f.path)
      f.rewind
      blob = ActiveStorage::Blob.create_and_upload!(
        io: f, filename: filename, content_type: content_type
      )
      url = Rails.application.routes.url_helpers.rails_blob_url(
        blob, host: ENV.fetch("APP_HOST", "http://localhost:3000")
      )
      job.update!(status: "completed", file_url: url, completed_at: Time.current)
    end

    WhatsappNotificationJob.perform_later(job.id, "export_ready")

  rescue => e
    job.update!(status: "failed", error_message: e.message)
    Rails.logger.error("[ExportLeads] Failed #{export_job_id}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    raise
  end

  private

  def filter_leads(stall_owner, filters)
    leads = stall_owner.leads.includes(:visitor).order(scanned_at: :desc)
    leads = leads.where(temperature: filters["temperature"]) if filters["temperature"].present?
    leads = leads.where(status: filters["status"])           if filters["status"].present?
    if filters["start_date"].present? && filters["end_date"].present?
      range = Date.parse(filters["start_date"])..Date.parse(filters["end_date"])
      leads = leads.where(scanned_at: range.map { |d| d.beginning_of_day }..range.map { |d| d.end_of_day })
    end
    leads.to_a
  end
end

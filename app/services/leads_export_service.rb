# app/services/leads_export_service.rb
class LeadsExportService
  def initialize(stall_owner, filters = {})
    @stall_owner = stall_owner
    @filters = filters || {}
  end

  def generate
    leads = filter_leads

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.styles do |s|
      header_style = s.add_style(
        bg_color: "1a1a2e",
        fg_color: "FFFFFF",
        b: true,
        sz: 11,
        alignment: { horizontal: :center }
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
          visitor = lead.visitor

          style =
            case lead.temperature
            when "hot" then hot_style
            when "warm" then warm_style
            when "cold" then cold_style
            else
              idx.even? ? normal_even : normal_odd
            end

          sheet.add_row(
            [
              idx + 1,
              visitor.full_name,
              visitor.mobile_number,
              visitor.email,
              visitor.business_name,
              visitor.business_category,
              visitor.profession,
              visitor.location,
              visitor.designation,
              lead.temperature.to_s.upcase,
              lead.status.to_s.titleize,
              "#{lead.interest_rating}/5",
              lead.notes,
              lead.requirements,
              lead.budget.present? ? "₹#{lead.budget}" : "",
              lead.follow_up_date,
              lead.remarks,
              lead.scanned_at&.strftime("%d %b %Y %H:%M")
            ],
            style: style
          )
        end

        sheet.column_widths 4, 25, 14, 25, 25, 18, 15, 15, 15, 10, 12, 7, 30, 20, 12, 14, 30, 18
      end

      workbook.add_worksheet(name: "Summary") do |sheet|
        sheet.add_row(["Metric", "Count"], style: header_style)
        sheet.add_row(["Total Leads", leads.count])
        sheet.add_row(["Hot Leads", leads.count { |l| l.temperature == "hot" }])
        sheet.add_row(["Warm Leads", leads.count { |l| l.temperature == "warm" }])
        sheet.add_row(["Cold Leads", leads.count { |l| l.temperature == "cold" }])
        sheet.add_row(["Converted", leads.count { |l| l.status == "converted" }])
        sheet.add_row(["Exported On", Time.current.strftime("%d %b %Y %H:%M")])
        sheet.add_row(["Stall", "#{@stall_owner.company_name} (#{@stall_owner.stall_number})"])
      end
    end

    package.to_stream.read
  end

  private

  def filter_leads
    leads = @stall_owner.leads.includes(:visitor).order(scanned_at: :desc)

    leads = leads.where(temperature: @filters["temperature"]) if @filters["temperature"].present?
    leads = leads.where(status: @filters["status"]) if @filters["status"].present?

    if @filters["start_date"].present? && @filters["end_date"].present?
      start_time = Date.parse(@filters["start_date"]).beginning_of_day
      end_time = Date.parse(@filters["end_date"]).end_of_day
      leads = leads.where(scanned_at: start_time..end_time)
    end

    leads
  end
end
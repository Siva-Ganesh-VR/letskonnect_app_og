class AnalyticsService
  def self.update_event_analytics(event_id)
    event    = Event.find(event_id)
    visitors = event.visitors.verified
    leads    = event.leads

    event.event_analytics.update!(
      total_visitors:         visitors.count,
      total_leads:            leads.count,
      total_scans:            leads.count,
      hot_leads:              leads.where(temperature: "hot").count,
      warm_leads:             leads.where(temperature: "warm").count,
      cold_leads:             leads.where(temperature: "cold").count,
      visitors_by_category:   visitors.group(:business_category).count.compact,
      visitors_by_location:   visitors.group(:location).count.compact,
      visitors_by_profession: visitors.group(:profession).count.compact,
      hourly_registrations:   hourly_breakdown(visitors, :created_at),
      stall_performance:      stall_perf(event)
    )
  end

  def self.update_stall_analytics(stall_owner_id, event_id)
    stall = StallOwner.find(stall_owner_id)
    leads = stall.leads

    stall_analytics = stall.stall_analytics ||
                      StallAnalytics.create!(stall_owner: stall, event_id: event_id)

    stall_analytics.update!(
      total_leads:      leads.count,
      hot_leads:        leads.where(temperature: "hot").count,
      warm_leads:       leads.where(temperature: "warm").count,
      cold_leads:       leads.where(temperature: "cold").count,
      converted_leads:  leads.where(status: "converted").count,
      leads_by_hour:    hourly_breakdown(leads, :scanned_at),
      leads_by_category: leads.joins(:visitor).group("visitors.business_category").count.compact
    )
  end

  private

  def self.hourly_breakdown(scope, time_col)
    scope
      .where("#{time_col} >= ?", 24.hours.ago)
      .group_by { |r| r.send(time_col).hour }
      .transform_values(&:count)
      .sort
      .to_h
  end

  def self.stall_perf(event)
    event.stall_owners.active.order(total_leads_count: :desc).map do |s|
      { id: s.id, name: s.company_name, stall_number: s.stall_number, leads: s.total_leads_count }
    end
  end
end

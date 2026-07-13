class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # Speeds up stall owner leads list (most frequent query during event)
    # GET /api/v1/stall_owner/leads?page=1&per_page=20
    unless index_exists?(:leads, [:stall_owner_id, :scanned_at])
      add_index :leads, [:stall_owner_id, :scanned_at],
                name: "index_leads_on_stall_owner_id_and_scanned_at"
    end

    # Speeds up lead update by primary key (already fast, but ensure)
    # PATCH /api/v1/stall_owner/leads/:id
    unless index_exists?(:leads, [:stall_owner_id, :updated_at])
      add_index :leads, [:stall_owner_id, :updated_at],
                name: "index_leads_on_stall_owner_id_and_updated_at"
    end

    # Speeds up WhatsApp webhook visitor lookup
    # POST /api/v1/webhooks/whatsapp/webhook
    # Looks up: Visitor.find_or_initialize_by(mobile_number:, event_id:)
    unless index_exists?(:visitors, [:mobile_number, :event_id])
      add_index :visitors, [:mobile_number, :event_id],
                name: "index_visitors_on_mobile_number_and_event_id"
    end

    # Speeds up visitor state machine updates
    # UPDATE visitors SET whatsapp_state = ? WHERE id = ?
    unless index_exists?(:visitors, [:event_id, :whatsapp_state])
      add_index :visitors, [:event_id, :whatsapp_state],
                name: "index_visitors_on_event_id_and_whatsapp_state"
    end
  end
end

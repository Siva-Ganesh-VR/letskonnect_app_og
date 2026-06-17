class StallAnalytics < ApplicationRecord
  belongs_to :stall_owner
  belongs_to :event
end

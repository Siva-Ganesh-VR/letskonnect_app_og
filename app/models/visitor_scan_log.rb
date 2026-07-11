class VisitorScanLog < ApplicationRecord
  belongs_to :event
  belongs_to :stall_owner
  belongs_to :visitor

end
class VisitorAnswer < ApplicationRecord
  belongs_to :visitor

  validates :question_key, presence: true
end
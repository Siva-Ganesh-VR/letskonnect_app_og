class TemplateMessage < ApplicationRecord
  belongs_to :template

  validates :message, presence: true
end
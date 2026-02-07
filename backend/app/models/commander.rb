class Commander < ApplicationRecord
  has_many :decklists, dependent: :destroy, inverse_of: :commander

  validates :name, presence: true, uniqueness: true
  validates :rank, presence: true
  validates :edhrec_url, presence: true
end

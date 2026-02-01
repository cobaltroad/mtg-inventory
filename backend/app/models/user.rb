class User < ApplicationRecord
  # The email address used to identify the seeded default user.
  # Shared by seeds.rb and ApplicationController#current_user so the value
  # is defined in exactly one place.
  DEFAULT_EMAIL = "default@mtg-inventory.local"

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
end

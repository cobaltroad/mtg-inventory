# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ---------------------------------------------------------------------------
# Default user -- MVP placeholder until OAuth / session auth is added.
# All per-user data (inventory, wishlist, alerts) belongs to this record.
# ---------------------------------------------------------------------------
User.find_or_create_by!(email: User::DEFAULT_EMAIL) do |user|
  user.name = "Default User"
end

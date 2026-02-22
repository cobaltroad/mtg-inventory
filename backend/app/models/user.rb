# @deprecated The DEFAULT_EMAIL user is being phased out in favor of Discord OAuth.
#             See issue #226 for migration details.
class User < ApplicationRecord
  DEFAULT_EMAIL = "default@mtg-inventory.local" # @deprecated
  DISCORD_PROVIDER = "discord"

  has_many :oauth_providers, dependent: :destroy
  has_many :collection_items, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def self.find_or_create_by_discord(auth_info)
    uid = auth_info["uid"]
    email = auth_info["info"]["email"]
    name = auth_info["info"]["name"]

    oauth_provider = OauthProvider.find_by(provider: DISCORD_PROVIDER, uid: uid)

    if oauth_provider
      oauth_provider.user
    else
      user = User.find_or_create_by!(email: email) do |u|
        u.name = name
      end

      migrate_seeded_inventory(user)

      OauthProvider.create!(
        provider: DISCORD_PROVIDER,
        uid: uid,
        user: user
      )

      user
    end
  end

  def self.migrate_seeded_inventory(new_user)
    seeded_user = find_by(email: DEFAULT_EMAIL)
    return unless seeded_user
    return unless seeded_user.collection_items.any?

    seeded_user.collection_items.each do |item|
      new_user.collection_items.create!(
        card_id: item.card_id,
        collection_type: item.collection_type,
        quantity: item.quantity,
        finish: item.finish,
        language: item.language,
        acquired_date: item.acquired_date,
        acquired_price_cents: item.acquired_price_cents,
        card_name: item.card_name,
        set_name: item.set_name,
        released_at: item.released_at
      )
    rescue => e
      Rails.logger.error("Failed to migrate collection item #{item.id}: #{e.message}")
    end
  end
end

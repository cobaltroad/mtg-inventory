class User < ApplicationRecord
  DEFAULT_EMAIL = "default@mtg-inventory.local"

  has_many :oauth_providers, dependent: :destroy
  has_many :collection_items, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def self.find_or_create_by_discord(auth_info)
    provider_info = auth_info["provider"]
    uid = auth_info["uid"]
    email = auth_info["info"]["email"]
    name = auth_info["info"]["name"]

    oauth_provider = OauthProvider.find_by(provider: provider_info, uid: uid)

    if oauth_provider
      oauth_provider.user
    else
      user = User.find_or_create_by!(email: email) do |u|
        u.name = name
      end

      OauthProvider.create!(
        provider: provider_info,
        uid: uid,
        user: user
      )

      user
    end
  end
end

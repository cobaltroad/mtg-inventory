class WishlistController < ApplicationController
  include CollectionItemActions

  private

  def collection_type
    "wishlist"
  end
end

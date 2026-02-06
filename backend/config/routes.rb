Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Collection resources — inventory and wishlist are independent scoped
  # views over the same collection_items table.  Using scope rather than
  # namespace so controllers live at the top level (matching the existing
  # flat-controller convention in this app).
  scope ENV.fetch("PUBLIC_API_PATH", "/api") do
    mount ActiveStorage::Engine => "/rails/active_storage"

    resources :inventory, only: [ :index, :create, :update, :destroy ] do
      collection do
        post :move_from_wishlist
      end
    end

    resources :wishlist, only: [ :index, :create, :update, :destroy ]

    get "cards/search", to: "card_search#index"
    get "cards/:id/printings", to: "card_printings#show"
  end

  # Test/development-only probe route to verify current_user resolution.
  # Never exposed in production.
  if Rails.env.test? || Rails.env.development?
    get "test/current_user_email" => "current_user_probe#show"
  end
end

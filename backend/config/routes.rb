Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Test/development-only probe route to verify current_user resolution.
  # Never exposed in production.
  if Rails.env.test? || Rails.env.development?
    get "test/current_user_email" => "current_user_probe#show"
  end
end

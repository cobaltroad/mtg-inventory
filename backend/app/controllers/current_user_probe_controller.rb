# Lightweight controller used exclusively for testing that current_user
# is resolved correctly without any authentication credentials.
# Routes to this controller are only mounted in test and development.
class CurrentUserProbeController < ApplicationController
  def show
    render json: { email: current_user.email }
  end
end

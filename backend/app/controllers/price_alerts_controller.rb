class PriceAlertsController < ApplicationController
  # GET /api/price_alerts
  # Returns active (non-dismissed) price alerts for a user,
  # limited to the top 10 most recent alerts.
  def index
    user_id = params[:user_id]
    alerts = PriceAlert.for_user(User.find(user_id))
                       .active
                       .recent
                       .limit(10)

    render json: alerts
  end

  # PATCH /api/price_alerts/:id/dismiss
  # Marks a price alert as dismissed.
  def dismiss
    user_id = params[:user_id]
    alert = PriceAlert.find_by(id: params[:id])

    if alert.nil?
      render json: { error: "Alert not found" }, status: :not_found
      return
    end

    if alert.user_id != user_id.to_i
      render json: { error: "Forbidden" }, status: :forbidden
      return
    end

    alert.dismiss!
    render json: { success: true }, status: :ok
  end
end

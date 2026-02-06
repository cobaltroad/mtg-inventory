class PriceAlertsController < ApplicationController
  # GET /api/price_alerts
  # Returns active (non-dismissed) price alerts for the current user,
  # limited to the top 10 most recent alerts.
  def index
    alerts = PriceAlert.for_user(current_user)
                       .active
                       .recent
                       .limit(10)

    render json: alerts
  end

  # PATCH /api/price_alerts/:id/dismiss
  # Marks a price alert as dismissed.
  def dismiss
    alert = PriceAlert.find_by(id: params[:id])

    if alert.nil?
      render json: { error: "Alert not found" }, status: :not_found
      return
    end

    if alert.user_id != current_user.id
      render json: { error: "Forbidden" }, status: :forbidden
      return
    end

    alert.dismiss!
    render json: { success: true }, status: :ok
  end
end

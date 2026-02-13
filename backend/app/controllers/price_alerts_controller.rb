class PriceAlertsController < ApplicationController
  # GET /api/price_alerts
  # Returns active (non-dismissed) price alerts for the current user,
  # limited to the top 10 most recent alerts.
  # Enriches each alert with card name from Scryfall.
  def index
    alerts = PriceAlert.for_user(current_user)
                       .active
                       .recent
                       .limit(10)

    # Enrich alerts with card names
    enriched_alerts = alerts.map do |alert|
      card_name = fetch_card_name(alert.card_id)
      alert.as_json.merge(card_name: card_name)
    end

    render json: enriched_alerts
  end

  private

  # Fetches the card name for a given card ID using CardDetailsService.
  # Returns nil if the card details cannot be fetched.
  def fetch_card_name(card_id)
    card_details = CardDetailsService.new(card_id: card_id).call
    card_details&.dig(:name)
  rescue StandardError => e
    Rails.logger.error("Failed to fetch card name for #{card_id}: #{e.message}")
    nil
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

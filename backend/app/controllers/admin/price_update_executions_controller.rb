class Admin::PriceUpdateExecutionsController < ApplicationController
  # GET /api/admin/price_update_executions
  def index
    executions = PriceUpdateExecution.all

    # Filter by status if provided
    if params[:status].present?
      executions = executions.where(status: params[:status])
    end

    # Filter by mode if provided
    if params[:mode].present?
      executions = executions.where(mode: params[:mode])
    end

    # Filter by date range if provided
    if params[:start_date].present?
      start_date = Date.parse(params[:start_date])
      executions = executions.where("started_at >= ?", start_date)
    end

    if params[:end_date].present?
      end_date = Date.parse(params[:end_date]).end_of_day
      executions = executions.where("started_at <= ?", end_date)
    end

    # Order by most recent first
    executions = executions.order(started_at: :desc)

    # Limit results (default 50, max 50)
    limit = params[:limit]&.to_i || 50
    limit = [ limit, 50 ].min
    executions = executions.limit(limit)

    render json: executions.map { |e| execution_json(e) }
  rescue Date::Error
    # Invalid date format - return success with empty array or current results
    render json: []
  rescue ArgumentError
    # Invalid status enum - return empty array
    render json: []
  end

  # GET /api/admin/price_update_executions/:id
  def show
    execution = PriceUpdateExecution.find_by(id: params[:id])

    if execution.nil?
      render json: { error: "Execution not found" }, status: :not_found
      return
    end

    render json: execution_json(execution)
  end

  # GET /api/admin/price_update_executions/stats
  def stats
    total = PriceUpdateExecution.count
    successful = PriceUpdateExecution.where(status: :success).count
    failed = PriceUpdateExecution.where(status: :failure).count
    partial = PriceUpdateExecution.where(status: :partial_success).count

    success_rate = total.zero? ? 0.0 : (successful.to_f / total * 100).round(2)

    # Last 24 hours stats
    last_24h = PriceUpdateExecution.where("started_at >= ?", 24.hours.ago)
    last_24h_total = last_24h.count
    last_24h_successful = last_24h.where(status: :success).count
    last_24h_success_rate = last_24h_total.zero? ? 0.0 : (last_24h_successful.to_f / last_24h_total * 100).round(2)
    last_24h_failed = last_24h.where(status: :failure).count

    # Last 7 days average duration
    last_7d = PriceUpdateExecution.where("started_at >= ?", 7.days.ago).where.not(finished_at: nil)
    last_7d_avg_duration = if last_7d.any?
      durations = last_7d.map(&:execution_time_seconds).compact
      durations.any? ? (durations.sum / durations.size).round(2) : 0.0
    else
      0.0
    end

    # Total cards processed today
    total_cards_today = PriceUpdateExecution
      .where("started_at >= ?", Time.current.beginning_of_day)
      .sum(:cards_attempted)

    render json: {
      total_executions: total,
      successful_executions: successful,
      failed_executions: failed,
      partial_success_executions: partial,
      success_rate: success_rate,
      last_24h_success_rate: last_24h_success_rate,
      last_7d_avg_duration: last_7d_avg_duration,
      total_cards_processed_today: total_cards_today,
      failed_count_last_24h: last_24h_failed
    }
  end

  private

  # ---------------------------------------------------------------------------
  # Serialize execution to JSON
  # ---------------------------------------------------------------------------
  def execution_json(execution)
    {
      id: execution.id,
      started_at: execution.started_at&.iso8601(3),
      finished_at: execution.finished_at&.iso8601(3),
      status: execution.status,
      mode: execution.mode,
      cards_attempted: execution.cards_attempted,
      cards_succeeded: execution.cards_succeeded,
      cards_failed: execution.cards_failed,
      cards_skipped: execution.cards_skipped,
      price_alerts_created: execution.price_alerts_created,
      execution_time_seconds: execution.execution_time_seconds,
      success_rate: execution.success_rate,
      error_summary: execution.error_summary,
      created_at: execution.created_at.iso8601(3),
      updated_at: execution.updated_at.iso8601(3)
    }
  end
end

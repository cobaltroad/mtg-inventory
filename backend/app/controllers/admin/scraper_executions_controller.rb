class Admin::ScraperExecutionsController < ApplicationController
  # GET /api/admin/scraper_executions
  def index
    executions = ScraperExecution.all

    # Filter by status if provided
    if params[:status].present?
      executions = executions.where(status: params[:status])
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
  end

  # GET /api/admin/scraper_executions/:id
  def show
    execution = ScraperExecution.find_by(id: params[:id])

    if execution.nil?
      render json: { error: "Execution not found" }, status: :not_found
      return
    end

    render json: execution_json(execution)
  end

  # GET /api/admin/scraper_executions/stats
  def stats
    total = ScraperExecution.count
    successful = ScraperExecution.where(status: :success).count
    failed = ScraperExecution.where(status: :failure).count
    partial = ScraperExecution.where(status: :partial_success).count

    success_rate = total.zero? ? 0.0 : (successful.to_f / total * 100).round(2)

    render json: {
      total_executions: total,
      successful_executions: successful,
      failed_executions: failed,
      partial_success_executions: partial,
      success_rate: success_rate
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
      commanders_attempted: execution.commanders_attempted,
      commanders_succeeded: execution.commanders_succeeded,
      commanders_failed: execution.commanders_failed,
      total_cards_processed: execution.total_cards_processed,
      execution_time_seconds: execution.execution_time_seconds,
      success_rate: execution.success_rate,
      error_summary: execution.error_summary,
      created_at: execution.created_at.iso8601(3),
      updated_at: execution.updated_at.iso8601(3)
    }
  end
end

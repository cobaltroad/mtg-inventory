class Admin::ImageCacheExecutionsController < ApplicationController
  # GET /api/admin/image_cache_executions
  def index
    executions = ImageCacheExecution.all

    # Filter by status if provided
    if params[:status].present?
      executions = executions.where(status: params[:status])
    end

    # Filter by card_id if provided
    if params[:card_id].present?
      executions = executions.where(card_id: params[:card_id])
    end

    # Filter by collection_item_id if provided
    if params[:collection_item_id].present?
      executions = executions.where(collection_item_id: params[:collection_item_id])
    end

    # Filter by cache_hit if provided
    if params[:cache_hit].present?
      cache_hit_value = params[:cache_hit].to_s.downcase == "true"
      executions = executions.where(cache_hit: cache_hit_value)
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

    # Limit results (default 100, max 100)
    limit = params[:limit]&.to_i || 100
    limit = [ limit, 100 ].min
    executions = executions.limit(limit)

    render json: executions.map { |e| execution_json(e) }
  rescue Date::Error
    # Invalid date format - return success with empty array
    render json: []
  rescue ArgumentError
    # Invalid status enum - return empty array
    render json: []
  end

  # GET /api/admin/image_cache_executions/:id
  def show
    execution = ImageCacheExecution.find_by(id: params[:id])

    if execution.nil?
      render json: { error: "Execution not found" }, status: :not_found
      return
    end

    render json: execution_json(execution)
  end

  # GET /api/admin/image_cache_executions/stats
  def stats
    total = ImageCacheExecution.count
    successful = ImageCacheExecution.where(status: :success).count
    failed = ImageCacheExecution.where(status: :failure).count
    skipped = ImageCacheExecution.where(status: :skipped).count

    success_rate = total.zero? ? 0.0 : (successful.to_f / total * 100).round(2)

    # Cache hit rate (only among successful executions)
    cache_hits = ImageCacheExecution.where(status: :success, cache_hit: true).count
    cache_hit_rate = successful.zero? ? 0.0 : (cache_hits.to_f / successful * 100).round(2)

    # Last 24 hours stats
    last_24h = ImageCacheExecution.where("started_at >= ?", 24.hours.ago)
    last_24h_total = last_24h.count
    last_24h_successful = last_24h.where(status: :success).count
    last_24h_success_rate = last_24h_total.zero? ? 0.0 : (last_24h_successful.to_f / last_24h_total * 100).round(2)
    last_24h_failed = last_24h.where(status: :failure).count
    last_24h_downloads = last_24h.where(downloaded: true).count

    # Last 7 days average duration
    last_7d = ImageCacheExecution.where("started_at >= ?", 7.days.ago).where.not(finished_at: nil)
    last_7d_avg_duration = if last_7d.any?
      durations = last_7d.map(&:execution_time_seconds).compact
      durations.any? ? (durations.sum / durations.size).round(2) : 0.0
    else
      0.0
    end

    render json: {
      total_executions: total,
      successful_executions: successful,
      failed_executions: failed,
      skipped_executions: skipped,
      success_rate: success_rate,
      cache_hit_rate: cache_hit_rate,
      last_24h_success_rate: last_24h_success_rate,
      last_7d_avg_duration: last_7d_avg_duration,
      total_downloads_last_24h: last_24h_downloads,
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
      collection_item_id: execution.collection_item_id,
      card_id: execution.card_id,
      cache_hit: execution.cache_hit,
      downloaded: execution.downloaded,
      file_size_bytes: execution.file_size_bytes,
      execution_time_seconds: execution.execution_time_seconds,
      error_message: execution.error_message,
      created_at: execution.created_at.iso8601(3),
      updated_at: execution.updated_at.iso8601(3)
    }
  end
end

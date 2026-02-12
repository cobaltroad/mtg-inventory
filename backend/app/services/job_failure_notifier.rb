# frozen_string_literal: true

# Service to send failure alerts when scheduled background jobs fail.
# Supports multiple notification channels (email, Slack, webhooks).
#
# Usage:
#   JobFailureNotifier.notify(
#     id: job.id,
#     class_name: job.class_name,
#     failed_at: Time.current,
#     error_message: error.message,
#     error_backtrace: error.backtrace
#   )
#
# Configuration:
#   Set ADMIN_EMAIL environment variable for email alerts
#   Set SLACK_WEBHOOK_URL environment variable for Slack alerts
#   Set JOB_FAILURE_WEBHOOK_URL for custom webhooks
class JobFailureNotifier
  # Send failure alert using configured channels
  #
  # @param job_info [Hash] Job failure information
  # @option job_info [Integer] :id Job ID
  # @option job_info [String] :class_name Job class name
  # @option job_info [Time] :failed_at Failure timestamp
  # @option job_info [String] :error_message Error message
  # @option job_info [Array<String>] :error_backtrace Stack trace
  def self.notify(job_info)
    message = format_alert_message(job_info)

    # Log the failure
    Rails.logger.error("JOB FAILURE ALERT: #{message}")

    # Send via configured channels
    send_email_alert(message, job_info) if email_configured?
    send_slack_alert(message, job_info) if slack_configured?
    send_webhook_alert(message, job_info) if webhook_configured?

    # Also log to structured logs for monitoring systems
    Rails.logger.tagged("JobFailureAlert") do
      Rails.logger.error({
        event: "job_failed",
        job_id: job_info[:id],
        job_class: job_info[:class_name],
        failed_at: job_info[:failed_at],
        error: job_info[:error_message]
      }.to_json)
    end
  end

  # Format a human-readable alert message
  #
  # @param job_info [Hash] Job failure information
  # @return [String] Formatted alert message
  def self.format_alert_message(job_info)
    <<~MESSAGE
      ⚠️  Background Job Failed

      Job: #{job_info[:class_name]}
      Job ID: #{job_info[:id]}
      Failed At: #{job_info[:failed_at]&.strftime('%Y-%m-%d %H:%M:%S %Z')}

      Error: #{job_info[:error_message]}

      Stack Trace:
      #{job_info[:error_backtrace]&.first(5)&.join("\n") || 'N/A'}

      ---
      View logs: docker compose logs jobs
      Check queue: docker compose exec backend rails jobs:stats
    MESSAGE
  end

  # Check if email alerts are configured
  def self.email_configured?
    ENV["ADMIN_EMAIL"].present?
  end

  # Check if Slack alerts are configured
  def self.slack_configured?
    ENV["SLACK_WEBHOOK_URL"].present?
  end

  # Check if custom webhook is configured
  def self.webhook_configured?
    ENV["JOB_FAILURE_WEBHOOK_URL"].present?
  end

  # Send email alert (requires ActionMailer configuration)
  def self.send_email_alert(message, job_info)
    # TODO: Implement email delivery via ActionMailer
    # JobFailureMailer.job_failed(message, job_info).deliver_later
    Rails.logger.info("Email alert would be sent to: #{ENV['ADMIN_EMAIL']}")
  rescue StandardError => e
    Rails.logger.error("Failed to send email alert: #{e.message}")
  end

  # Send Slack webhook notification
  def self.send_slack_alert(message, job_info)
    require "net/http"
    require "json"

    uri = URI(ENV["SLACK_WEBHOOK_URL"])
    payload = {
      text: "🚨 Background Job Failure",
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Background Job Failed*\n\n" \
                  "*Job:* `#{job_info[:class_name]}`\n" \
                  "*Job ID:* #{job_info[:id]}\n" \
                  "*Failed At:* #{job_info[:failed_at]&.strftime('%Y-%m-%d %H:%M:%S %Z')}\n\n" \
                  "*Error:* #{job_info[:error_message]}"
          }
        }
      ]
    }

    Net::HTTP.post(uri, payload.to_json, "Content-Type" => "application/json")
  rescue StandardError => e
    Rails.logger.error("Failed to send Slack alert: #{e.message}")
  end

  # Send custom webhook notification
  def self.send_webhook_alert(message, job_info)
    require "net/http"
    require "json"

    uri = URI(ENV["JOB_FAILURE_WEBHOOK_URL"])
    payload = {
      event: "job_failure",
      job_id: job_info[:id],
      job_class: job_info[:class_name],
      failed_at: job_info[:failed_at]&.iso8601,
      error_message: job_info[:error_message],
      error_backtrace: job_info[:error_backtrace]&.first(10)
    }

    Net::HTTP.post(uri, payload.to_json, "Content-Type" => "application/json")
  rescue StandardError => e
    Rails.logger.error("Failed to send webhook alert: #{e.message}")
  end
end

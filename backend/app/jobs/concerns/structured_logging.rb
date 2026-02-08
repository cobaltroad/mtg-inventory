module StructuredLogging
  # ---------------------------------------------------------------------------
  # Log a structured event as JSON
  # ---------------------------------------------------------------------------
  def log_event(level:, event:, **context)
    data = {
      level: level.to_s.upcase,
      event: event,
      timestamp: Time.current.iso8601,
      component: self.class.name,
      **context
    }

    # Redact sensitive information
    json_message = redact_sensitive_data(data.to_json)

    case level
    when :info
      Rails.logger.info(json_message)
    when :warn
      Rails.logger.warn(json_message)
    when :error
      Rails.logger.error(json_message)
    when :debug
      Rails.logger.debug(json_message)
    else
      Rails.logger.info(json_message)
    end
  end

  # ---------------------------------------------------------------------------
  # Log an error with full context
  # ---------------------------------------------------------------------------
  def log_error(error:, **context)
    log_event(
      level: :error,
      event: "error_occurred",
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(5),
      **context
    )
  end

  # ---------------------------------------------------------------------------
  # Log a rate limit event
  # ---------------------------------------------------------------------------
  def log_rate_limit(service:, retry_after: nil)
    log_event(
      level: :warn,
      event: "rate_limit_encountered",
      service: service,
      retry_after_seconds: retry_after
    )
  end

  private

  # ---------------------------------------------------------------------------
  # Redact sensitive data from log messages
  # ---------------------------------------------------------------------------
  def redact_sensitive_data(message)
    # Redact common secret patterns
    redacted = message.dup

    # Redact API keys
    redacted.gsub!(/SCRYFALL_API_KEY[=:]\s*["']?[^"'\s,}]+["']?/i, "SCRYFALL_API_KEY=[REDACTED]")
    redacted.gsub!(/api_key[=:]\s*["']?[^"'\s,}]+["']?/i, "api_key=[REDACTED]")

    # Redact bearer tokens
    redacted.gsub!(/bearer\s+[a-zA-Z0-9_-]+/i, "bearer [REDACTED]")

    # Redact common secret variable patterns
    redacted.gsub!(/secret[=:]\s*["']?[^"'\s,}]+["']?/i, "secret=[REDACTED]")
    redacted.gsub!(/token[=:]\s*["']?[^"'\s,}]+["']?/i, "token=[REDACTED]")

    redacted
  end
end

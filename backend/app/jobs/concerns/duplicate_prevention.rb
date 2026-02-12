# frozen_string_literal: true

# Concern to prevent duplicate job execution for scheduled background jobs.
# Provides methods to check if a job is already running and prevent duplicate executions.
#
# Usage:
#   class MyJob < ApplicationJob
#     include DuplicatePrevention
#   end
#
#   MyJob.already_running?  # => true/false
#   MyJob.prevent_duplicate_execution!  # Raises error if job is running
module DuplicatePrevention
  extend ActiveSupport::Concern

  class_methods do
    # Check if this job class has any currently running instances
    #
    # @return [Boolean] true if job is running, false otherwise
    def already_running?
      SolidQueue::Job.where(
        class_name: name,
        finished_at: nil
      ).exists?
    end

    # Get information about the currently running job instance
    #
    # @return [Hash, nil] Job details (id, created_at, queue_name) or nil if not running
    def running_job_info
      job = SolidQueue::Job.where(
        class_name: name,
        finished_at: nil
      ).first

      return nil unless job

      {
        id: job.id,
        created_at: job.created_at,
        queue_name: job.queue_name
      }
    end

    # Prevent duplicate execution by raising an error if job is already running
    #
    # @raise [StandardError] if job is already running
    # @return [void]
    def prevent_duplicate_execution!
      return unless already_running?

      info = running_job_info
      raise StandardError, "#{name} is already running (Job ID: #{info[:id]}, Started: #{info[:created_at]})"
    end
  end
end

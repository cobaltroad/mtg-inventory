module ExecutionLoggingTestConcern
  extend ActiveSupport::Concern

  included do
    attr_reader :log_output
  end

  def setup
    super
    @log_output = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@log_output)
  end

  def teardown
    Rails.logger = @original_logger if @original_logger
    super
  end
end

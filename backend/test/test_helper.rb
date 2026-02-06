ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# ---------------------------------------------------------------------------
# Minitest 6 removed Object#stub (it was extracted to a separate gem that
# treats any value responding to :call as a factory, which breaks stubs on
# objects that legitimately have a #call method).  This minimal
# implementation unconditionally returns the replacement value, matching the
# behaviour the test suite expects.
# ---------------------------------------------------------------------------
class Object
  def stub(name, value)
    metaclass = singleton_class
    original = method(name)
    metaclass.define_method(name) { |*_a, **_kw, &_b| value }
    yield self
  ensure
    metaclass.define_method(name, original)
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # Comment out for now since we don't have a comprehensive fixture set
    # fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

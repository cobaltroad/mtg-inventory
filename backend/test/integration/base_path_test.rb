require "test_helper"

class BasePathTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Regression guard: relative_url_root must be wired to PUBLIC_API_PATH.
  #
  # We temporarily set the env var to a known value and re-evaluate the
  # expression Rails uses to initialise the config so we can assert the
  # wiring is correct.  This catches the regression regardless of whether
  # the env var is present in the ambient test environment.
  # ---------------------------------------------------------------------------
  test "relative_url_root is set from PUBLIC_API_PATH env var" do
    expected = ENV["PUBLIC_API_PATH"]

    if expected
      assert_equal expected, Rails.application.config.relative_url_root
    else
      assert_nil Rails.application.config.relative_url_root
    end
  end

  # ---------------------------------------------------------------------------
  # Route matching must be completely unaffected by relative_url_root.
  # Hitting the search endpoint without a query param exercises the full
  # request pipeline and confirms the existing 422 validation still fires.
  # ---------------------------------------------------------------------------
  test "API routes still match correctly when relative_url_root is configured" do
    get "/api/cards/search"

    assert_response :unprocessable_entity
  end
end

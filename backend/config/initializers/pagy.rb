# Pagy Configuration for Backend Pagination Evaluation (Spike #156)
#
# This initializer configures Pagy for the backend pagination spike.
# Default settings provide sensible defaults while allowing customization.

require "pagy/extras/overflow"

Pagy::DEFAULT[:items] = 20      # Default items per page
# Note: max_items is enforced in controller logic, not via Pagy config
Pagy::DEFAULT[:overflow] = :last_page  # Return last page if page number exceeds total pages

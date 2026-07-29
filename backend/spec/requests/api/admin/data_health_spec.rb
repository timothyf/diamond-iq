require "rails_helper"

RSpec.describe "Api::Admin::DataHealth", type: :request do
  around { |example| with_admin_api_token("test-admin-token", &example) }
  it "returns the current data-health report" do
    get api_admin_data_health_path, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to include(
      "status",
      "checked_at",
      "calculation_version",
      "summary",
      "checks"
    )
    expect(json_body.dig("data", "summary")).to include(
      "check_count" => 12,
      "healthy_count" => be_a(Integer),
      "warning_count" => be_a(Integer),
      "critical_count" => be_a(Integer),
      "affected_record_count" => be_a(Integer)
    )
    expect(json_body.dig("data", "checks").first).to include(
      "id",
      "category",
      "name",
      "status",
      "affected_count",
      "description",
      "recommendation",
      "examples"
    )
  end
end

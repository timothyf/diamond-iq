require "rails_helper"

RSpec.describe "Api::SavedAnalyses", type: :request do
  let(:owner) { create_user(role: "viewer") }
  let(:owner_headers) { user_headers(owner) }
  let(:attributes) do
    {
      name: "Detroit pitch leaderboard",
      analysis_type: "stat_explorer",
      visibility: "private",
      reproducible_url: "/explore?category=pitchData&pitch_type=FF",
      state: {
        category: "pitchData",
        filters: { pitchType: "FF" }
      }
    }
  end

  it "creates a named, owned, reproducible view for any signed-in user" do
    expect do
      with_admin_api_token("configured-system-token") do
        post api_saved_analyses_path, params: attributes, headers: owner_headers, as: :json
      end
    end.to change(SavedAnalysis, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.fetch("data")).to include(
      "name" => "Detroit pitch leaderboard",
      "analysis_type" => "stat_explorer",
      "visibility" => "private",
      "reproducible_url" => "/explore?category=pitchData&pitch_type=FF",
      "share_url" => match(%r{\A/saved/\d+\z}),
      "editable" => true
    )
    expect(json_body.dig("data", "owner", "id")).to eq(owner.id)
    expect(json_body.dig("data", "state", "filters", "pitchType")).to eq("FF")
    expect(AuditLog.where(auditable_type: "SavedAnalysis", action: "created", user: owner)).to exist
  end

  it "applies private, organization, and public sharing scopes" do
    private_view = SavedAnalysis.create!(attributes.merge(owner: owner))
    organization_view = SavedAnalysis.create!(
      attributes.merge(owner: owner, name: "Organization comparison", analysis_type: "player_comparison",
        visibility: "organization", reproducible_url: "/compare?left=1&right=2")
    )
    public_view = SavedAnalysis.create!(
      attributes.merge(owner: owner, name: "Public team state", analysis_type: "team_dashboard",
        visibility: "public", reproducible_url: "/teams/1?season=2026&tab=roster")
    )

    get api_saved_analyses_path
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to eq([ public_view.id ])
    expect(json_body.dig("data", 0, "owner")).not_to have_key("email")

    other_user = create_user(role: "scout")
    get api_saved_analyses_path, headers: user_headers(other_user)
    expect(json_body.fetch("data").pluck("id")).to contain_exactly(organization_view.id, public_view.id)

    get api_saved_analyses_path, headers: owner_headers
    expect(json_body.fetch("data").pluck("id")).to contain_exactly(private_view.id, organization_view.id, public_view.id)

    get api_saved_analysis_path(private_view), headers: user_headers(other_user)
    expect(response).to have_http_status(:forbidden)

    admin = create_user(role: "administrator")
    get api_saved_analysis_path(private_view), headers: user_headers(admin)
    expect(response).to have_http_status(:ok)
  end

  it "lets owners change sharing and delete while rejecting other users" do
    analysis = SavedAnalysis.create!(attributes.merge(owner: owner))
    other_user = create_user(role: "analyst")

    patch api_saved_analysis_path(analysis), params: { visibility: "organization" },
      headers: user_headers(other_user), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(analysis.reload.visibility).to eq("private")

    patch api_saved_analysis_path(analysis), params: { visibility: "organization" },
      headers: owner_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(analysis.reload.visibility).to eq("organization")
    expect(AuditLog.where(auditable_type: "SavedAnalysis", action: "updated", user: owner)).to exist

    expect do
      delete api_saved_analysis_path(analysis), headers: owner_headers
    end.to change(SavedAnalysis, :count).by(-1)
    expect(response).to have_http_status(:no_content)
  end

  it "rejects external or protocol-relative reproducible URLs" do
    post api_saved_analyses_path,
      params: attributes.merge(reproducible_url: "https://example.com/private"),
      headers: owner_headers,
      as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to include("Reproducible url must be a local application URL")
  end
end

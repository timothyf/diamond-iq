require "rails_helper"

RSpec.describe "Api::Notes", type: :request do
  let(:team) { create_team }
  let(:player) { create_player(team: team) }
  let(:author) { create_user(role: "analyst") }
  let(:author_headers) { user_headers(author) }

  it "creates attributed, dated notes with reusable normalized tags and an initial revision" do
    expect do
      post api_notes_path,
        params: {
          target_type: "player",
          target_id: player.id,
          body: "Fastball shape improved after the grip adjustment.",
          note_date: "2026-07-28",
          tags: [ "Pitch Design", " follow-up ", "pitch design" ]
        },
        headers: author_headers,
        as: :json
    end.to change(Note, :count).by(1)
      .and change(Tag, :count).by(2)
      .and change(NoteRevision, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "author", "id")).to eq(author.id)
    expect(json_body.dig("data", "note_date")).to eq("2026-07-28")
    expect(json_body.dig("data", "tags").pluck("name")).to eq([ "follow-up", "pitch design" ])
    expect(json_body.dig("data", "history_count")).to eq(1)
    expect(AuditLog.where(auditable_type: "Note", action: "created", user: author)).to exist
  end

  it "shares public-resource notes with authenticated staff but only lets the author edit them" do
    post api_notes_path,
      params: { target_type: "player", target_id: player.id, body: "Original observation" },
      headers: author_headers,
      as: :json
    note = Note.last
    other = create_user(role: "scout")

    get api_notes_path,
      params: { target_type: "player", target_id: player.id },
      headers: user_headers(other)
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "body")).to eq("Original observation")
    expect(json_body.dig("data", 0, "editable")).to be(false)

    patch api_note_path(note),
      params: { body: "Someone else's edit" },
      headers: user_headers(other),
      as: :json
    expect(response).to have_http_status(:forbidden)

    patch api_note_path(note),
      params: { body: "Updated observation", tags: [ "reviewed" ] },
      headers: author_headers,
      as: :json
    expect(response).to have_http_status(:ok)
    expect(note.reload.body).to eq("Updated observation")
    expect(note.revisions.count).to eq(2)

    get history_api_note_path(note), headers: author_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("version")).to eq([ 2, 1 ])
    expect(json_body.dig("data", 0, "editor", "id")).to eq(author.id)
  end

  it "requires authentication and write-capable roles" do
    get api_notes_path, params: { target_type: "player", target_id: player.id }
    expect(response).to have_http_status(:unauthorized)

    viewer = create_user(role: "viewer")
    post api_notes_path,
      params: { target_type: "player", target_id: player.id, body: "Viewer note" },
      headers: user_headers(viewer),
      as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "inherits lineup ownership and supports canonical comparison targets" do
    scenario = LineupScenario.create!(
      team: team,
      owner: author,
      season: 2026,
      scenario_date: Date.new(2026, 7, 29),
      name: "Late-inning lineup"
    )
    other = create_user(role: "coach")

    get api_notes_path,
      params: { target_type: "lineup_scenario", target_id: scenario.id },
      headers: user_headers(other)
    expect(response).to have_http_status(:forbidden)

    second_player = create_player(team: team)
    comparison_key = "#{second_player.id}:#{player.id}"
    post api_notes_path,
      params: { target_type: "comparison", target_id: comparison_key, body: "Prefer the left player for this role." },
      headers: author_headers,
      as: :json
    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "target_id")).to eq([ player.id, second_player.id ].sort.join(":"))
    expect(json_body.dig("data", "target_metadata", "left_player_id")).to be_present
    expect(json_body.dig("data", "target_metadata", "right_player_id")).to be_present
  end

  it "archives notes while preserving their revision history" do
    post api_notes_path,
      params: { target_type: "player", target_id: player.id, body: "Temporary note" },
      headers: author_headers,
      as: :json
    note = Note.last

    delete api_note_path(note), headers: author_headers
    expect(response).to have_http_status(:no_content)
    expect(note.reload.archived_at).to be_present
    expect(note.revisions.order(:version).pluck(:action)).to eq(%w[created archived])

    get api_notes_path,
      params: { target_type: "player", target_id: player.id },
      headers: author_headers
    expect(json_body.fetch("data")).to eq([])
  end
end

require_dependency Rails.root.join("app/services/note_target.rb").to_s
require_dependency Rails.root.join("app/policies/note_policy.rb").to_s
require_dependency Rails.root.join("app/models/tag.rb").to_s
require_dependency Rails.root.join("app/models/note_tagging.rb").to_s
require_dependency Rails.root.join("app/models/note_revision.rb").to_s
require_dependency Rails.root.join("app/models/note.rb").to_s

module Api
  class NotesController < ApplicationController
    skip_before_action :authenticate_unsafe_api_request, only: [ :create, :update, :destroy ]
    before_action :require_authenticated_user

    def index
      target = requested_target
      return render_invalid_target unless target.valid?
      return render_forbidden unless NotePolicy.new(current_user, target: target).read?

      notes = Note.active
        .where(target_type: target.type, target_key: target.key)
        .includes(:author, :last_edited_by, :tags, :revisions)
        .recent_first
      render json: { data: notes.map { |note| serialize(note) } }
    end

    def show
      note = find_note
      return render_forbidden unless NotePolicy.new(current_user, note).read?

      render json: { data: serialize(note) }
    end

    def create
      target = requested_target
      return render_invalid_target unless target.valid?
      return render_forbidden unless NotePolicy.new(current_user, target: target).create?

      note = Note.transaction do
        created = Note.create!(
          author: current_user,
          last_edited_by: current_user,
          target_type: target.type,
          target_key: target.key,
          target_metadata: target.metadata,
          body: note_params.fetch(:body),
          note_date: note_params[:note_date].presence || Date.current
        )
        replace_tags(created)
        created.record_revision!(editor: current_user, action: "created")
        created
      end
      AuditLog.record!(user: current_user, action: "created", record: note, changes: note.attributes)
      render json: { data: serialize(note.reload) }, status: :created
    rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing => error
      render_validation(error)
    end

    def update
      note = find_note
      return render_forbidden unless NotePolicy.new(current_user, note).update?

      before = note_snapshot(note)
      Note.transaction do
        note.update!(
          note_params.slice(:body, :note_date).to_h.merge(last_edited_by: current_user)
        )
        replace_tags(note) if note_params.key?(:tags)
        note.record_revision!(editor: current_user, action: "updated")
      end
      AuditLog.record!(
        user: current_user,
        action: "updated",
        record: note,
        changes: { "before" => before, "after" => note_snapshot(note.reload) }
      )
      render json: { data: serialize(note) }
    rescue ActiveRecord::RecordInvalid => error
      render_validation(error)
    end

    def destroy
      note = find_note
      return render_forbidden unless NotePolicy.new(current_user, note).destroy?

      Note.transaction do
        note.update!(archived_at: Time.current, last_edited_by: current_user)
        note.record_revision!(editor: current_user, action: "archived")
      end
      AuditLog.record!(user: current_user, action: "archived", record: note, changes: note.saved_changes)
      head :no_content
    end

    def history
      note = find_note
      return render_forbidden unless NotePolicy.new(current_user, note).read?

      revisions = note.revisions.includes(:editor).order(version: :desc)
      render json: {
        data: revisions.map do |revision|
          {
            id: revision.id,
            version: revision.version,
            action: revision.action,
            body: revision.body,
            note_date: revision.note_date,
            tags: revision.tag_names,
            editor: serialize_user(revision.editor),
            created_at: revision.created_at
          }
        end
      }
    end

    private

    def requested_target
      NoteTarget.new(type: params[:target_type], key: params[:target_id] || params[:target_key])
    end

    def find_note
      Note.includes(:author, :last_edited_by, :tags, :revisions).find(params[:id])
    end

    def note_params
      params.permit(:body, :note_date, :target_type, :target_id, :target_key, tags: [])
    end

    def replace_tags(note)
      tags = Array(note_params[:tags]).filter_map do |value|
        name = value.to_s.strip.downcase.gsub(/\s+/, " ").presence
        next if name.blank?

        Tag.find_or_create_by!(name: name) { |tag| tag.created_by = current_user }
      rescue ActiveRecord::RecordNotUnique
        Tag.find_by!(name: name)
      end
      note.tags = tags.uniq
    end

    def serialize(note)
      {
        id: note.id,
        target_type: note.target_type,
        target_id: note.target_key,
        target_metadata: note.target_metadata,
        body: note.body,
        note_date: note.note_date,
        tags: note.tags.sort_by(&:name).map { |tag| serialize_tag(tag) },
        author: serialize_user(note.author),
        last_edited_by: serialize_user(note.last_edited_by),
        editable: NotePolicy.new(current_user, note).update?,
        history_count: note.revisions.size,
        created_at: note.created_at,
        updated_at: note.updated_at
      }
    end

    def serialize_tag(tag)
      { id: tag.id, name: tag.name, color: tag.color }
    end

    def serialize_user(user)
      { id: user.id, name: user.name, role: user.role }
    end

    def note_snapshot(note)
      {
        "body" => note.body,
        "note_date" => note.note_date,
        "tags" => note.tags.pluck(:name)
      }
    end

    def render_invalid_target
      render json: { message: "The note target does not exist or is unsupported" }, status: :unprocessable_content
    end

    def render_forbidden
      render json: { message: "You are not authorized to access notes for this resource" }, status: :forbidden
    end

    def render_validation(error)
      message = error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
      render json: { message: message }, status: :unprocessable_content
    end
  end
end

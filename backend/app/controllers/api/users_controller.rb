module Api
  class UsersController < ApplicationController
    before_action :require_authenticated_user

    def index
      users = User.active.where(system_account: false).order(:name, :email)
      render json: { data: users.map { |user| serialize_user(user) } }
    end

    private

    def serialize_user(user)
      { id: user.id, name: user.name, email: user.email, role: user.role }
    end
  end
end

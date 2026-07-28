module Api
  module Admin
    class DataHealthsController < ApplicationController
      before_action :require_authenticated_user
      before_action :require_admin_user

      def show
        render json: { data: AdminDataHealthCheck.call }
      end
    end
  end
end

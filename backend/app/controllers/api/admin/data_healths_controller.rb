module Api
  module Admin
    class DataHealthsController < ApplicationController
      def show
        render json: { data: AdminDataHealthCheck.call }
      end
    end
  end
end

module Api
  class HomeController < ApplicationController
    def show
      snapshot = HomeSnapshotQuery.new(on: params[:date], league: params[:league]).result

      render json: { data: snapshot }
    end
  end
end

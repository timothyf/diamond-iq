Rails.application.routes.draw do
  namespace :api do
    namespace :admin do
      resources :tasks, only: [:index], param: :task_name do
        member do
          post :run
        end
      end
    end

    resources :players, only: [:index, :show]
    resources :teams, only: [:index, :show]
    resources :positions, only: [:index]
    resources :games, only: [:index, :show] do
      collection do
        get :upcoming
      end
    end
    resources :schedules, only: [:show]
    resources :roster_snapshots, only: [:index]
    resources :team_memberships, only: [] do
      collection do
        get :active_today
        get :active_range
        get :roster_status
      end
    end
    resources :player_season_stats do
      collection do
        post :import
        post :download
      end
    end
    resources :pitch_data, only: [:index] do
      collection do
        post :import
        post :download
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end

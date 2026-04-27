require "sidekiq/web"

Rails.application.routes.draw do
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  devise_for :users,
    controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations"
    }

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :rewards, only: [ :index ]
      resource :user, only: :show do
        resource :points, only: :show, module: :user
        resources :redemptions, only: [ :index, :create, :show ], module: :user
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end

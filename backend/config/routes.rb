Rails.application.routes.draw do
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
        resources :redemptions, only: [ :index, :create ], module: :user
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end

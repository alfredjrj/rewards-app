Rails.application.routes.draw do
  devise_for :users,
    controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations"
    }

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :rewards, only: [:index]
    end
    get "me", to: "users#me"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end

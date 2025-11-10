# frozen_string_literal: true
Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Hot reload for development
  mount Hotwire::Livereload::Engine, at: "/hotwire-livereload" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # GitHub webhook endpoint
  post "github/webhook", to: "github_webhook#create"

  # Projects and Runs
  resources :projects, only: [:index, :show, :new, :create, :edit, :update] do
    member do
      post :trigger_orchestrator
    end
    resources :runs, only: [:index]
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "projects#index"
end

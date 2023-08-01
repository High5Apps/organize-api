Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :connections,  only: [:create]
      resources :orgs, only: [:create]
      resources :users, only: [:create, :show]

      get 'connection_preview', to: 'connections#preview'
      get 'org', to: 'orgs#my_org', as: 'my_org'
    end
  end
end

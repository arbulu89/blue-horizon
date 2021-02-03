# frozen_string_literal: true

require 'root_constraint'

Rails.application.routes.draw do
  root to: redirect('/home'), constraints: RootConstraint.new
  root to: redirect('/welcome')

  get '/welcome', to: 'welcome#index'
  # switch paths
  put '/welcome/reset-session', to: 'welcome#reset_session', as: 'reset_session'

  # Cluster size
  resource :cluster, only: [:show, :update]
  # Additional data
  resource :variables, only: [:show, :update]

  # Show plan
  resource :plan, only: [:show, :update]
  # Deploy
  resource :deploy, only: [:update, :destroy]

  resources :dashboards, only: [:show]

  resource :deploy do
    get 'send_current_status', on: :member
  end
  get '/home', to: 'home#index'
  get '/download', to: 'download#download'
  get '/resources', to: 'resources#index'
end

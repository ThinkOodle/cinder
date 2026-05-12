Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/", to: "uploads#create"
  get  "/:slug", to: "uploads#show", as: :upload, constraints: { slug: /[A-Za-z0-9]+/ }

  root to: "pages#root"
end

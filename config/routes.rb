Rails.application.routes.draw do
  post "/", to: "uploads#create"
  get  "/:slug", to: "uploads#show", as: :upload, constraints: { slug: /[A-Za-z0-9]+\.log/ }

  get "up" => "rails/health#show", as: :rails_health_check

  root to: "pages#root"
end

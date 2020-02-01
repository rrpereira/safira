defmodule SafiraWeb.Router do
  use SafiraWeb, :router

  alias Safira.Guardian

  if Mix.env == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :jwt_authenticated do
    plug Guardian.AuthPipeline
  end

  scope "/", SafiraWeb do
    get "/", PageController, :index
  end

  scope "/api", SafiraWeb do
    pipe_through :api

    scope "/auth" do
      post "/sign_up", AuthController, :sign_up
      post "/sign_in", AuthController, :sign_in
      
      resources "/passwords", PasswordController, only: [:create, :update]
    end

    scope "/v1" do
      get "/is_registered/:id", AuthController, :is_registered

      pipe_through :jwt_authenticated

      get "/user", AuthController, :user
      get "/attendee", AuthController, :attendee
      get "/leaderboard", LeaderboardController, :index

      resources "/badges", BadgeController, only: [:index, :show]
      resources "/attendees", AttendeeController, except: [:create]
      resources "/referrals", ReferralController, only: [:show]
      resources "/companies", CompanyController, only: [:index, :show]
      resources "/redeems", RedeemController, only: [:create]
    end
  end
end

defmodule FlowApiWeb.Router do
  use FlowApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug FlowApiWeb.AuthPipeline
  end

  scope "/api", FlowApiWeb do
    pipe_through :api

    # Auth routes (no authentication required)
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  scope "/api", FlowApiWeb do
    pipe_through [:api, :auth]

    # Auth (authenticated)
    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :current_user

    # Dashboard
    get "/dashboard/forecast", DashboardController, :forecast
    get "/dashboard/action-items", DashboardController, :action_items
    post "/dashboard/action-items/:id/dismiss", DashboardController, :dismiss_action_item
    get "/dashboard/summary", DashboardController, :summary

    # Contacts
    resources "/contacts", ContactController, except: [:new, :edit] do
      post "/communication", ContactController, :add_communication
      get "/ai-insights", ContactController, :insights
    end
    get "/contacts-stats", ContactController, :stats

    # Deals
    resources "/deals", DealController, except: [:new, :edit] do
      patch "/stage", DealController, :update_stage
      post "/activities", DealController, :add_activity
    end
    get "/deals-forecast", DealController, :forecast
    get "/deals-stage-stats", DealController, :stage_stats

    # Conversations/Messages
    resources "/conversations", ConversationController, except: [:new, :edit, :create, :delete] do
      post "/messages", ConversationController, :send_message
      patch "/priority", ConversationController, :update_priority
      patch "/archive", ConversationController, :archive
      post "/tags", ConversationController, :add_tag
    end
    get "/messages/:id/ai-analysis", MessageController, :analysis
    post "/messages/smart-compose", MessageController, :smart_compose
    get "/messages/templates", MessageController, :templates
    get "/messages-stats", ConversationController, :stats
    get "/messages-sentiment-overview", ConversationController, :sentiment_overview

    # Calendar
    resources "/calendar/events", CalendarController, except: [:new, :edit] do
      patch "/status", CalendarController, :update_status
      post "/outcome", CalendarController, :add_outcome
      get "/preparation", CalendarController, :preparation
    end
    post "/calendar/smart-scheduling", CalendarController, :smart_schedule
    get "/calendar-stats", CalendarController, :stats

    # Notifications
    resources "/notifications", NotificationController, only: [:index, :delete] do
      patch "/read", NotificationController, :mark_read
    end
    get "/notifications-unread-count", NotificationController, :unread_count

    # Search
    get "/search", SearchController, :search

    # Tags
    resources "/tags", TagController, only: [:index, :create, :delete]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  # Commented out for API-only app
  # if Application.compile_env(:flow_api, :dev_routes) do
  #   import Phoenix.LiveDashboard.Router
  #
  #   scope "/dev" do
  #     pipe_through [:fetch_session, :protect_from_forgery]
  #
  #     live_dashboard "/dashboard", metrics: FlowApiWeb.Telemetry
  #     forward "/mailbox", Plug.Swoosh.MailboxPreview
  #   end
  # end
end

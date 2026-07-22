defmodule SipaexWeb.Router do
  use SipaexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SipaexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SipaexWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/dashboard", PageController, :dashboard
    get "/bank", PageController, :bank
    post "/petty-cash", PageController, :create_petty_cash
    delete "/petty-cash/:id", PageController, :delete_petty_cash
    get "/ledger", PageController, :ledger
    post "/ledger/accounts", PageController, :create_ledger_account
    post "/ledger/transactions", PageController, :create_ledger_transaction
    post "/ledger/exchange-differences", PageController, :create_ledger_exchange_difference
    get "/currencies", PageController, :currencies
    post "/currencies", PageController, :create_currency
    post "/currencies/default", PageController, :set_default_currency
    delete "/currencies/:currency_id", PageController, :delete_currency
  end

  # Other scopes may use custom stacks.
  # scope "/api", SipaexWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sipaex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SipaexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

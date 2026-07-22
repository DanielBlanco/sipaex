defmodule SipaexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SipaexWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :active_module, :string, default: "dashboard", doc: "the active top navigation module"
  attr :show_navigation, :boolean, default: true, doc: "whether to show the app top navigation"
  attr :organization, :any, default: nil, doc: "the active organization shown in the header"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 border-b border-base-300 bg-base-100/90 backdrop-blur">
      <div class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a
            href={if(@show_navigation, do: ~p"/dashboard", else: ~p"/")}
            class="flex w-fit items-center gap-3"
          >
            <span class="flex size-10 items-center justify-center rounded-lg bg-primary text-sm font-black text-primary-content shadow-sm">
              S
            </span>
            <span class="leading-tight">
              <span class="block text-sm font-bold tracking-wide text-base-content">SIPAE</span>
              <span class="block text-xs text-base-content/60">Gestión empresarial</span>
            </span>
          </a>
        </div>
        <div class="flex-none">
          <div class="flex items-center justify-end gap-3">
            <div
              :if={@show_navigation && @organization}
              id="app-organization-summary"
              class="hidden max-w-xl items-center gap-3 rounded-box border border-base-300 bg-base-200/70 px-4 py-2 text-right shadow-sm md:flex"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold leading-5">
                  {@organization.legal_name}
                </p>
                <div class="flex flex-wrap justify-end gap-x-3 gap-y-1 text-xs text-base-content/60">
                  <span>Cédula jurídica: {@organization.tax_id}</span>
                  <span>Moneda base: {@organization.base_currency.code}</span>
                </div>
              </div>
              <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-base-100 text-base-content/70">
                <.icon name="hero-building-office-2" class="size-5" />
              </span>
            </div>
            <.theme_toggle />
          </div>
        </div>
      </div>
    </header>

    <main class="min-h-[calc(100vh-4rem)] bg-base-200/60">
      <div class="mx-auto max-w-7xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :active_module, :string, required: true

  def top_navigation(assigns) do
    ~H"""
    <nav
      id="app-topnav"
      class="relative overflow-visible border-t border-base-300 px-4 sm:px-6 lg:px-8"
    >
      <div class="flex flex-wrap gap-1 overflow-visible py-2">
        <.nav_link
          title="Panel"
          href={~p"/dashboard"}
          icon="hero-squares-2x2"
          active={@active_module in ["", "dashboard"]}
        />
        <.nav_dropdown
          title="Ventas y compras"
          icon="hero-shopping-cart"
          active={@active_module in ["purchases", "sales"]}
        >
          <.nav_menu_link title="Compras" href="/purchases?l=1" icon="hero-shopping-bag" />
          <.nav_menu_link title="Ventas" href="/sales?l=1" icon="hero-shopping-cart" />
        </.nav_dropdown>
        <.nav_dropdown
          title="Gestión financiera"
          icon="hero-wallet"
          active={
            @active_module in ["currencies", "ledger", "bank", "dividends", "expenses", "taxes"]
          }
        >
          <.nav_menu_link title="Monedas" href="/currencies?l=1" icon="hero-currency-dollar" />
          <.nav_menu_link title="Cuenta corriente" href="/ledger?l=1" icon="hero-credit-card" />
          <.nav_menu_link title="Banco" href="/bank?l=1" icon="hero-building-library" />
          <.nav_menu_link
            title="Dividendos"
            href="/buy-module?module=Dividendos&l=1"
            icon="hero-banknotes"
          />
          <.nav_menu_link
            title="Gastos"
            href="/buy-module?module=Gastos&l=1"
            icon="hero-receipt-percent"
          />
          <.nav_menu_link title="Impuestos" href="/taxes?l=1" icon="hero-receipt-refund" />
        </.nav_dropdown>
        <.nav_dropdown
          title="Activos e inventario"
          icon="hero-cube"
          active={@active_module in ["fixed_assets", "inventory", "costs"]}
        >
          <.nav_menu_link
            title="Activos fijos"
            href="/fixed-assets?l=1"
            icon="hero-building-storefront"
          />
          <.nav_menu_link title="Inventario" href="/inventory?l=1" icon="hero-cube-transparent" />
          <.nav_menu_link title="Costos" href="/costs?l=1" icon="hero-chart-bar" />
        </.nav_dropdown>
        <.nav_dropdown
          title="Recursos humanos"
          icon="hero-users"
          active={@active_module in ["hr", "employees", "payroll"]}
        >
          <.nav_menu_link title="Personal" href="/hr/employees?l=1" icon="hero-user" />
          <.nav_menu_link title="Planilla" href="/hr/payroll?l=1" icon="hero-document-text" />
        </.nav_dropdown>
        <.nav_dropdown
          title="Contabilidad y reportes"
          icon="hero-document-chart-bar"
          active={
            @active_module in [
              "income_statement",
              "retained_earnings",
              "statement_of_position",
              "closing_adjustment"
            ]
          }
        >
          <.nav_menu_link
            title="Estado de resultados"
            href="/buy-module?module=Estado%20de%20Resultados&l=1"
            icon="hero-chart-pie"
          />
          <.nav_menu_link
            title="Estado de utilidades"
            href="/buy-module?module=Estado%20de%20Utilidades&l=1"
            icon="hero-presentation-chart-line"
          />
          <.nav_menu_link
            title="Estado de situación"
            href="/buy-module?module=Estado%20de%20Situacion&l=1"
            icon="hero-presentation-chart-bar"
          />
          <.nav_menu_link
            title="Ajuste de cierre"
            href="/buy-module?module=Ajuste%20de%20Cierre&l=1"
            icon="hero-adjustments-horizontal"
          />
        </.nav_dropdown>
      </div>
    </nav>
    """
  end

  attr :title, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  def nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "btn btn-sm shrink-0 gap-2 border-base-300 font-medium",
        @active && "btn-primary border-primary",
        !@active && "btn-ghost hover:bg-base-200"
      ]}
    >
      <.icon name={@icon} class="size-4" /> {@title}
    </a>
    """
  end

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  def nav_dropdown(assigns) do
    ~H"""
    <div class="group relative shrink-0">
      <button
        type="button"
        class={[
          "btn btn-sm shrink-0 gap-2 border-base-300 font-medium",
          @active && "btn-primary border-primary",
          !@active && "btn-ghost hover:bg-base-200"
        ]}
      >
        <.icon name={@icon} class="size-4" /> {@title}
        <.icon name="hero-chevron-down" class="size-3 opacity-60" />
      </button>
      <div class="invisible absolute left-0 top-full z-[80] min-w-64 pt-2 opacity-0 transition group-hover:visible group-hover:opacity-100 group-focus-within:visible group-focus-within:opacity-100">
        <ul class="menu w-64 rounded-box border border-base-300 bg-base-100 p-2 shadow-xl">
          {render_slot(@inner_block)}
        </ul>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true

  def nav_menu_link(assigns) do
    ~H"""
    <li>
      <a href={@href} class="gap-3">
        <.icon name={@icon} class="size-4 opacity-70" /> {@title}
      </a>
    </li>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end

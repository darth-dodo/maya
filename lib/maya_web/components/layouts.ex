defmodule MayaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MayaWeb, :html

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
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  # The default bottom padding keeps content clear of the Talk screen's pinned Talk button.
  attr :main_class, :string, default: "px-4 pt-2 pb-36 sm:px-6 lg:px-8"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="text-xl font-bold tracking-tight">Maya</a>
      </div>
      <div class="flex-none">
        <.theme_toggle />
      </div>
    </header>

    <main class={@main_class}>
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  The site footer for public pages: the wave and badges art from `docs/assets/footer.svg`,
  inline so it needs no image file (decorative, hidden from screen readers), and links to the home page, the factory page, the repo and its README.
  """
  def site_footer(assigns) do
    ~H"""
    <footer id="site-footer" class="site-footer">
      <%!-- legacy-colours:start footer-art (design-apply moves these onto tokens) --%>
      <svg
        class="footer-art"
        viewBox="0 0 1200 160"
        aria-hidden="true"
        preserveAspectRatio="xMidYMid slice"
      >
        <defs>
          <linearGradient id="footer-bg" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stop-color="#FBF4E4" />
            <stop offset="1" stop-color="#E4F1EE" />
          </linearGradient>
        </defs>
        <rect width="1200" height="160" fill="url(#footer-bg)" />
        <path
          d="M0 128 C 150 118, 300 136, 450 126 S 760 116, 900 128 S 1100 138, 1200 124 L1200 160 L0 160 Z"
          fill="#B9DAD5"
        />
        <path
          d="M0 144 C 160 136, 320 152, 500 142 S 820 134, 1000 146 S 1140 150, 1200 142 L1200 160 L0 160 Z"
          fill="#7FB2AD"
          opacity="0.8"
        />
        <g font-family="-apple-system, 'Segoe UI', Helvetica, Arial, sans-serif" text-anchor="middle">
          <text x="600" y="46" font-size="26" font-weight="700" fill="#12432F">
            Mudkip would approve.
          </text>
          <g
            fill="#FFFFFF"
            fill-opacity="0.6"
            stroke="#2F6B5E"
            stroke-width="2"
            stroke-dasharray="5 4"
          >
            <circle :for={n <- 0..7} cx={390 + n * 60} cy="88" r="18" />
          </g>
          <g font-size="15" font-weight="700" fill="#2F6B5E">
            <text :for={n <- 0..7} x={390 + n * 60} y="93">{n + 1}</text>
          </g>
        </g>
      </svg>
      <%!-- legacy-colours:end --%>
      <nav aria-label="About Maya" class="footer-links">
        <a href="/">Home</a>
        <a href="/factory">How Maya is built</a>
        <a href="https://github.com/darth-dodo/maya">GitHub repo</a>
        <a href="https://github.com/darth-dodo/maya#readme">README</a>
      </nav>
    </footer>
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
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
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
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
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
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

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

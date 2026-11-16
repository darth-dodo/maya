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

  attr :link, :atom,
    default: :talk,
    values: [:talk, :home],
    doc: "the header's one text link: Talk (to /talk) or Home (to /, on the Talk screen)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header id="site-header" class="site-header">
      <a href="/" class="site-wordmark">Maya</a>
      <div class="site-header-end">
        <a :if={@link == :talk} id="header-talk-link" href="/talk" class="header-link">Talk</a>
        <a :if={@link == :home} id="header-home-link" href="/" class="header-link">Home</a>
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
      <%!-- Colours come from the art-* classes in app.css (tokens), so the art follows the theme. --%>
      <svg
        class="footer-art"
        viewBox="0 0 1200 160"
        aria-hidden="true"
        preserveAspectRatio="xMidYMid slice"
      >
        <defs>
          <linearGradient id="footer-bg" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" class="art-sky-top" />
            <stop offset="1" class="art-sky-bottom" />
          </linearGradient>
        </defs>
        <rect width="1200" height="160" fill="url(#footer-bg)" />
        <path
          class="art-wave-back"
          d="M0 128 C 150 118, 300 136, 450 126 S 760 116, 900 128 S 1100 138, 1200 124 L1200 160 L0 160 Z"
        />
        <path
          class="art-wave-front"
          d="M0 144 C 160 136, 320 152, 500 142 S 820 134, 1000 146 S 1140 150, 1200 142 L1200 160 L0 160 Z"
        />
        <g text-anchor="middle">
          <text class="art-title" x="600" y="46" font-size="26" font-weight="700">
            Mudkip would approve.
          </text>
          <g class="art-slots" stroke-width="2" stroke-dasharray="5 4">
            <circle :for={n <- 0..7} cx={390 + n * 60} cy="88" r="18" />
          </g>
          <g class="art-numbers" font-size="15" font-weight="700">
            <text :for={n <- 0..7} x={390 + n * 60} y="93">{n + 1}</text>
          </g>
        </g>
      </svg>
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
  The theme toggle: one icon button, a moon by day and a sun at night. CSS on `data-theme` shows
  one labelled span, so the accessible name always says the action. The click handler is the
  head theme script in root.html.heex, so it works on pages without a LiveView socket.
  """
  def theme_toggle(assigns) do
    ~H"""
    <button id="theme-toggle" type="button" class="theme-toggle">
      <span class="theme-to-night">
        <span class="hero-moon size-6" aria-hidden="true"></span>
        <span class="sr-only">Switch to night</span>
      </span>
      <span class="theme-to-day">
        <span class="hero-sun size-6" aria-hidden="true"></span>
        <span class="sr-only">Switch to day</span>
      </span>
    </button>
    """
  end
end

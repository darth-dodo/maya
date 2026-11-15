defmodule MayaWeb.DesignTokensTest do
  use ExUnit.Case, async: true

  # Scenarios from openspec/specs/design-system/spec.md (tokens, contrast, daisyUI, scales, doc)

  defp css, do: File.read!("assets/css/app.css")
  defp doc_md, do: File.read!("docs/design-system.md")

  @colour_tokens ~w(bg sea surface ink muted action action-ink line hairline accent listen wait success error)
  @scale_tokens ~w(text-xs text-sm text-base text-lg text-xl text-2xl text-3xl
                   radius-sm radius-md radius-lg radius-pill shadow-1 shadow-2 duration ease
                   font-head font-body)

  # The deepest wash of the day Talk scene (design.md); the night scene is --maya-surface.
  @day_scene "#cfe7df"

  defp layer do
    case Regex.run(~r{/\* tokens:start \*/(.*)/\* tokens:end \*/}s, css(),
           capture: :all_but_first
         ) do
      [layer] -> layer
      nil -> flunk("no /* tokens:start */ ... /* tokens:end */ layer in app.css")
    end
  end

  # Every innermost `selector { declarations }` block in the layer, as {selector, %{prop => value}}.
  defp blocks do
    ~r/([^{}]+)\{([^{}]*)\}/
    |> Regex.scan(layer(), capture: :all_but_first)
    |> Enum.map(fn [selector, body] ->
      decls =
        for decl <- String.split(body, ";"),
            [prop, value] <- [String.split(decl, ":", parts: 2)],
            into: %{},
            do: {String.trim(prop), String.trim(value)}

      {selector |> String.split("\n") |> List.last() |> String.trim(), decls}
    end)
  end

  defp scope(selector) do
    case Enum.find(blocks(), fn {sel, _} -> sel == selector end) do
      {_, decls} -> decls
      nil -> flunk("no #{selector} block in the token layer")
    end
  end

  defp day, do: scope(":root")
  defp night, do: scope(~s(:root[data-theme="dark"]))
  defp night_media, do: scope(~s|:root:not([data-theme="light"])|)

  defp daisy_theme(name) do
    Enum.find_value(blocks(), fn {sel, decls} ->
      if String.starts_with?(sel, "@plugin") and decls["name"] == ~s("#{name}"), do: decls
    end) || flunk("no daisyUI theme #{name}")
  end

  defp luminance("#" <> hex) do
    hex
    |> Base.decode16!(case: :mixed)
    |> :binary.bin_to_list()
    |> Enum.map(fn c ->
      s = c / 255
      if s <= 0.04045, do: s / 12.92, else: :math.pow((s + 0.055) / 1.055, 2.4)
    end)
    |> then(fn [r, g, b] -> 0.2126 * r + 0.7152 * g + 0.0722 * b end)
  end

  defp ratio(a, b) do
    [hi, lo] = Enum.sort([luminance(a), luminance(b)], :desc)
    (hi + 0.05) / (lo + 0.05)
  end

  test "every colour token is defined for day and both night scopes" do
    for scope <- [day(), night(), night_media()], token <- @colour_tokens do
      assert Map.has_key?(scope, "--maya-#{token}"), "--maya-#{token} missing"
    end

    assert night() |> Map.take(Enum.map(@colour_tokens, &"--maya-#{&1}")) ==
             night_media() |> Map.take(Enum.map(@colour_tokens, &"--maya-#{&1}"))
  end

  test "hairline is transparent by day and gold at night" do
    assert day()["--maya-hairline"] == "transparent"
    assert night()["--maya-hairline"] == "#b58a2a"
  end

  test "text pairs reach 4.5:1 and state rings 3:1 in both themes" do
    for {theme, t, scene} <- [
          {:day, day(), @day_scene},
          {:night, night(), night()["--maya-surface"]}
        ] do
      c = &t["--maya-#{&1}"]

      text = [
        {"ink", c.("ink"), c.("bg")},
        {"ink on surface", c.("ink"), c.("surface")},
        {"muted", c.("muted"), c.("bg")},
        {"muted on scene", c.("muted"), scene},
        {"accent", c.("accent"), c.("bg")},
        {"accent on surface", c.("accent"), c.("surface")},
        {"success", c.("success"), c.("bg")},
        {"error", c.("error"), c.("bg")},
        {"action-ink on action", c.("action-ink"), c.("action")}
      ]

      non_text = [{"listen", c.("listen"), scene}, {"wait", c.("wait"), scene}]

      for {name, fg, bg} <- text,
          do: assert(ratio(fg, bg) >= 4.5, "#{theme} #{name}: #{Float.round(ratio(fg, bg), 2)}")

      for {name, fg, bg} <- non_text,
          do: assert(ratio(fg, bg) >= 3.0, "#{theme} #{name}: #{Float.round(ratio(fg, bg), 2)}")
    end

    assert ratio(day()["--maya-action"], day()["--maya-bg"]) >= 4.5
  end

  test "daisyUI primary is the action token and no Phoenix purple is left" do
    for name <- ["light", "dark"] do
      assert daisy_theme(name)["--color-primary"] == "var(--maya-action)"
      assert daisy_theme(name)["--color-primary-content"] == "var(--maya-action-ink)"
    end

    refute css() =~ "oklch("
  end

  test "type, shape, depth and motion scales are defined, with no zero blur shadow" do
    for token <- @scale_tokens, do: assert(Map.has_key?(day(), "--maya-#{token}"), token)

    shadows =
      ~r/(?:box-shadow|--maya-shadow-\d|--maya-glow):([^;}]+)/
      |> Regex.scan(css(), capture: :all_but_first)
      |> Enum.flat_map(fn [value] -> String.split(value, ~r/,(?![^(]*\))/) end)

    assert length(shadows) > 4

    for shadow <- shadows do
      # Lengths only: drop colour and var() functions, keep offset x, offset y, blur, spread.
      lengths =
        shadow
        |> String.replace(~r/[a-z-]+\([^)]*\)/, "")
        |> String.split()
        |> Enum.filter(&(&1 =~ ~r/^-?[\d.]/))

      if lengths != [] do
        blur = Enum.at(lengths, 2, "0")
        refute blur =~ ~r/^0(\.0+)?(px|rem)?$/, "zero blur shadow: #{String.trim(shadow)}"
      end
    end
  end

  test "the design system doc names every token in the layer" do
    tokens = ~r/--maya-[a-z0-9-]+/ |> Regex.scan(layer()) |> List.flatten() |> Enum.uniq()

    assert length(tokens) >= length(@colour_tokens) + length(@scale_tokens)

    for token <- tokens,
        do: assert(doc_md() =~ "`#{token}`", "#{token} not in docs/design-system.md")
  end

  test "both fonts ship with their SIL OFL 1.1 licence" do
    for family <- ["Fraunces", "Inter"] do
      assert File.read!("priv/static/fonts/OFL-#{family}.txt") =~
               "SIL Open Font License, Version 1.1"
    end
  end
end

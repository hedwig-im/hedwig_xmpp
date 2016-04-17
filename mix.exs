defmodule HedwigXMPP.Mixfile do
  use Mix.Project

  @version "1.0.0-rc.3"

  def project do
    [app: :hedwig_xmpp,
     name: "Hedwig XMPP",
     version: @version,
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     description: "An XMPP adapter for Hedwig",
     deps: deps]
  end

  def application do
    [applications: [:logger, :hedwig, :romeo]]
  end

  defp deps do
    [{:hedwig, "1.0.0-rc.4"},
     {:romeo, "~> 0.5"}]
  end

  defp package do
    [files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Sonny Scroggin"],
     licenses: ["MIT"],
     links: %{
       "GitHub" => "https://github.com/hedwig-im/hedwig"
     }]
  end
end

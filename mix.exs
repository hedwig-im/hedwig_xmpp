defmodule HedwigXMPP.Mixfile do
  use Mix.Project

  @version "1.0.0-rc.4"

  def project do
    [app: :hedwig_xmpp,
     name: "Hedwig XMPP",
     version: @version,
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     description: "An XMPP adapter for Hedwig",
     deps: deps()]
  end

  def application do
    [applications: [:logger, :hedwig, :romeo]]
  end

  defp deps do
    [{:hedwig, github: "hedwig-im/hedwig"},
     {:romeo, "~> 0.6"}]
  end

  defp package do
    [files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Sonny Scroggin"],
     licenses: ["MIT"],
     links: %{
       "GitHub" => "https://github.com/hedwig-im/hedwig_xmpp"
     }]
  end
end

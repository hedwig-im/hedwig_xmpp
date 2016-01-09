defmodule HedwigXMPP.Mixfile do
  use Mix.Project

  @version "1.0.0-rc1"

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
    [{:exml, github: "esl/exml"},
     {:hedwig, "~> 1.0.0-rc1"},
     {:romeo, "~> 0.4"}]
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

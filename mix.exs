defmodule HedwigXMPP.Mixfile do
  use Mix.Project

  def project do
    [app: :hedwig_xmpp,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :hedwig, :romeo]]
  end

  defp deps do
    [{:hedwig, path: "../hedwig"},
     {:romeo, "~> 0.1"}]
  end
end

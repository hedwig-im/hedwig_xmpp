defmodule HedwigXMPP.Mixfile do
  use Mix.Project

  def project do
    [app: :hedwig_xmpp,
     version: "1.0.0-rc0",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :hedwig, :romeo]]
  end

  defp deps do
    [{:exml, github: "esl/exml"},
     {:hedwig, github: "hedwig-im/hedwig"},
     {:romeo, "~> 0.2"}]
  end
end

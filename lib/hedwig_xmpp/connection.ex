defmodule Hedwig.Adapters.XMPP.Connection do
  @behaviour Hedwig.Adapters.Connection

  def connect(opts) do
    Romeo.Connection.start_link(opts)
  end
end

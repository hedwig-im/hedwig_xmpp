defmodule Hedwig.Adapters.XMPP do
  use Hedwig.Adapter, :romeo

  def send(pid, msg) do
    Romeo.Connection.send(pid, msg)
  end
end

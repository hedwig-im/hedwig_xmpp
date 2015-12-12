defmodule Hedwig.Adapters.XMPP.Connection do
  @behaviour Hedwig.Adapters.Connection

  def connect(opts) do
    opts = Keyword.put_new(opts, :nickname, opts[:name])
    Romeo.Connection.start_link(opts)
  end
end

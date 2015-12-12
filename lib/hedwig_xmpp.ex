defmodule Hedwig.Adapters.XMPP do
  use Hedwig.Adapter, :romeo
  use Romeo.XML

  import Kernel, except: [send: 2]

  require Logger

  ## Adapter API

  def send(pid, %Hedwig.Message{} = msg) do
    GenServer.cast(pid, {:send, msg})
  end

  def reply(pid, %Hedwig.Message{} = msg) do
    GenServer.cast(pid, {:reply, msg})
  end

  def emote(pid, %Hedwig.Message{} = msg) do
    GenServer.cast(pid, {:emote, msg})
  end

  ## Callbacks

  def handle_cast({:send, %{text: text} = msg}, %{conn: conn} = state) do
    msg = romeo_message(msg)
    Romeo.Connection.send(conn, %{msg | body: text})
    {:noreply, state}
  end

  def handle_cast({:reply, %{user: user, text: text} = msg}, %{conn: conn} = state) do
    msg = romeo_message(msg)
    Romeo.Connection.send(conn, %{msg | body: "#{user.name}: #{text}"})
    {:noreply, state}
  end

  def handle_cast({:emote, %{text: text} = msg}, %{conn: conn} = state) do
    msg = romeo_message(msg)
    Romeo.Connection.send(conn, %{msg | body: "/me #{text}"})
    {:noreply, state}
  end

  def handle_info({:stanza, xmlstreamstart()}, state) do
    {:noreply, state}
  end

  def handle_info({:stanza, xmlstreamend()}, state) do
    exit(:stream_ended)
    {:noreply, state}
  end

  def handle_info({:stanza, %Message{type: "error"} = msg}, state) do
    Logger.error fn -> "There was an error: #{inspect msg}" end
    {:noreply, state}
  end

  def handle_info({:stanza, %Message{body: "", payload: payload, type: "groupchat"} = msg}, state) do
    Logger.warn fn -> "Topic? #{inspect msg}" end
    {:noreply, state}
  end

  def handle_info({:stanza, %Message{from: from} = msg}, %{robot: robot, opts: opts} = state) do
    unless from_self?(msg, opts[:name]) do
      Hedwig.Robot.handle_message(robot, hedwig_message(msg))
    end
    {:noreply, state}
  end

  def handle_info({:resource_bound, resource}, %{robot: robot, opts: opts} = state) do
    Hedwig.Robot.register_name(robot, opts[:jid])
    Hedwig.Robot.register_name(robot, opts[:jid] <> "/" <> resource)
    {:noreply, state}
  end

  def handle_info(:connection_ready, %{conn: conn, robot: robot, opts: opts} = state) do
    if Keyword.get(opts, :send_presence, true) do
      Romeo.Connection.send(conn, Romeo.Stanza.presence)
    end

    if Keyword.get(opts, :join_rooms, true) do
      for {room, _opts} <- opts[:rooms] do
        Romeo.Connection.send(conn, Romeo.Stanza.join(room, opts[:name]))
      end
    end

    Hedwig.Robot.after_connect(robot)

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn fn -> "Adapter received unhandled message: #{inspect msg}" end
    {:noreply, state}
  end

  ## Helpers

  defp from_self?(%Message{from: %{resource: name}, type: "groupchat"}, name) do
    true
  end
  defp from_self?(%Message{from: %{user: name}}, name) do
    true
  end
  defp from_self?(_, _), do: false

  defp hedwig_message(%Romeo.Stanza.Message{body: body, from: from, type: type} = msg) do
    {room, user} = extract_room_and_user(msg)

    %Hedwig.Message{
      adapter: {__MODULE__, self},
      ref: make_ref(),
      room: room,
      text: body,
      type: type,
      user: user
    }
  end

  defp romeo_message(%Hedwig.Message{room: room, type: type, text: text, user: user}) do
    %Romeo.Stanza.Message{
      to: send_to(type, room, user),
      type: type,
      body: text
    }
  end

  defp extract_room_and_user(%Romeo.Stanza.Message{from: from, type: "groupchat"}) do
    room = Romeo.JID.bare(from)
    user = %{
      id: Romeo.JID.resource(from),
      room: room,
      jid: to_string(from),
      name: Romeo.JID.resource(from)
    }

    {room, user}
  end
  defp extract_room_and_user(%Romeo.Stanza.Message{from: from}) do
    user = %{
      id: Romeo.JID.user(from),
      room: nil,
      jid: to_string(from),
      name: Romeo.JID.user(from)
    }
    {nil, user}
  end

  defp send_to("groupchat", room, _user) do
    Romeo.JID.bare(room)
  end
  defp send_to(_type, _room, user),
    do: Romeo.JID.parse(user.jid)
end

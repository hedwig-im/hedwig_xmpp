defmodule Hedwig.Adapters.XMPP do
  @moduledoc false

  use Hedwig.Adapter
  use Romeo.XML

  require Logger

  defmodule State do
    defstruct conn: nil,
              jid_mapping: %{},
              opts: nil,
              robot: nil,
              rooms: [],
              roster: []
  end

  ## Callbacks

  def init({robot, opts}) do
    connection_opts = Keyword.put_new(opts, :nickname, opts[:name])
    {:ok, conn} = Romeo.Connection.start_link(connection_opts)
    {:ok, %State{conn: conn, opts: opts, robot: robot}}
  end

  def handle_cast({:send, %{text: text} = msg}, %{conn: conn} = state) do
    case text do
      xmlel() ->
        Romeo.Connection.send(conn, text)
      _ ->
        msg = romeo_message(msg)
        Romeo.Connection.send(conn, %{msg | body: text})
    end
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

  def handle_cast({:rooms_results, %IQ{xml: xml}}, state) do
    rooms =
      xml
      |> Romeo.XML.subelement("query")
      |> Romeo.XML.subelements("item")
      |> Enum.map(&Romeo.XML.attr(&1, "jid"))

    {:noreply, %{state | rooms: rooms}}
  end

  def handle_cast({:roster_results, %IQ{xml: xml}}, state) do
    roster =
      xml
      |> Romeo.XML.subelement("query")
      |> Romeo.XML.subelements("item")
      |> Enum.map(&Romeo.XML.attr(&1, "jid"))
      |> Enum.reduce(%{}, &(Map.put(&2, &1, %{})))

    {:noreply, %{state | roster: roster}}
  end

  def handle_info({:stanza, xmlstreamstart()}, state) do
    {:noreply, state}
  end

  def handle_info({:stanza, xmlstreamend()}, state) do
    exit(:stream_ended)
    {:noreply, state}
  end

  def handle_info({:stanza, %{type: "error"} = stanza}, state) do
    Logger.error fn -> "There was an error: #{inspect stanza}" end
    {:noreply, state}
  end

  def handle_info({:stanza, %Message{body: "", type: "groupchat"}}, state) do
    # Most likely a room topic
    {:noreply, state}
  end

  def handle_info({:stanza, %Message{} = msg}, %{robot: robot, opts: opts} = state) do
    unless from_self?(msg, opts[:name]) do
      Hedwig.Robot.handle_message(robot, hedwig_message(msg, state.jid_mapping))
    end
    {:noreply, state}
  end

  def handle_info({:stanza, %Presence{from: from, xml: xml}}, state) do
    state =
      if from_room?(from, state.rooms) do
        real_jid = real_jid_from_room_presence(xml)
        update_in(state.jid_mapping, &(Map.put(&1, from.full, real_jid)))
      else
        state
      end
    {:noreply, state}
  end

  def handle_info({:resource_bound, _resource}, %{robot: robot, opts: opts} = state) do
    Hedwig.Robot.register(robot, opts[:name])
    {:noreply, state}
  end

  def handle_info(:connection_ready, %{conn: conn, robot: robot, opts: opts} = state) do
    conn
    |> get_roster(opts)
    |> request_all_rooms(opts)
    |> send_presence(opts)
    |> join_rooms(opts)

    Hedwig.Robot.after_connect(robot)

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn fn -> "Adapter received unhandled message: #{inspect msg}" end
    {:noreply, state}
  end

  ## Helpers

  defp real_jid_from_room_presence(xml) do
    case Romeo.XML.subelements(xml, "x") do
      [] ->
        nil
      elems ->
        try do
          elems
          |> Enum.filter(&contains_muc_user_namespace?/1)
          |> Enum.at(0)
          |> Romeo.XML.subelement("item")
          |> Romeo.XML.attr("jid")
        catch
          _ -> nil
        end
    end
  end

  defp contains_muc_user_namespace?(xmlel(attrs: attrs)) do
    Enum.any?(attrs, fn {k, v} -> k == "xmlns" && v == ns_muc_user end)
  end

  defp get_roster(conn, _opts) do
    stanza = Romeo.Stanza.get_roster
    id = Romeo.XML.attr(stanza, "id")
    Romeo.Connection.send(conn, stanza)

    receive do
      {:stanza, %IQ{id: ^id, type: "result"} = iq} ->
        GenServer.cast(self, {:roster_results, iq})
    end

    conn
  end

  defp request_all_rooms(conn, opts) do
    rooms = Keyword.get(opts, :rooms)
    if rooms do
      stanza =
        rooms
        |> hd
        |> elem(0)
        |> Romeo.JID.server
        |> Romeo.Stanza.disco_items

      id = Romeo.XML.attr(stanza, "id")
      Romeo.Connection.send(conn, stanza)

      receive do
        {:stanza, %IQ{id: ^id, type: "result"} = iq} ->
          GenServer.cast(self, {:rooms_results, iq})
      end
    end

    conn
  end

  defp send_presence(conn, opts) do
    if Keyword.get(opts, :send_presence, true) do
      Romeo.Connection.send(conn, Romeo.Stanza.presence)
    end

    conn
  end

  defp join_rooms(conn, opts) do
    rooms = Keyword.get(opts, :rooms, [])
    if Keyword.get(opts, :join_rooms, true) do
      for {room, room_opts} <- rooms do
        Romeo.Connection.send(conn, Romeo.Stanza.join(room, opts[:name], room_opts))
      end
    end

    conn
  end

  defp from_room?(from, rooms) do
    Romeo.JID.bare(from) in rooms
  end

  defp from_self?(%Message{from: %{resource: name}, type: "groupchat"}, name) do
    true
  end
  defp from_self?(%Message{from: %{user: name}}, name) do
    true
  end
  defp from_self?(_, _), do: false

  defp hedwig_message(%Message{body: body, type: type} = msg, mapping) do
    {room, user} = extract_room_and_user(msg, mapping)

    %Hedwig.Message{
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

  defp extract_room_and_user(%Message{from: from, type: "groupchat"}, mapping) do
    room = Romeo.JID.bare(from)
    user = %{
      id: Romeo.JID.resource(from),
      room: room,
      jid: mapping[from.full] || from.full,
      name: Romeo.JID.resource(from)
    }

    {room, user}
  end
  defp extract_room_and_user(%Romeo.Stanza.Message{from: from}, _mapping) do
    user = %{
      id: Romeo.JID.user(from),
      room: nil,
      jid: from.full,
      name: Romeo.JID.user(from)
    }
    {nil, user}
  end

  defp send_to("groupchat", room, _user) do
    Romeo.JID.bare(room)
  end
  defp send_to(_type, _room, user) do
    Romeo.JID.parse(user.jid)
  end
end

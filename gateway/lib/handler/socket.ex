defmodule Handler.Socket do
  alias Peer.Pool, as: Peer
  import Model.Record
  require Lager
  @bahaviour :sockjs_service

  fields peer: nil,
         ip_address: nil,
         peer_id: nil,
         peer_scope: nil,
         peer_ref: nil

  def sockjs_init(connection, _state) do
    [{:headers, headers}] = Enum.filter connection.info, fn({k, _v}) -> k == :headers end
    [{:'x-real-ip', ip_address}] = Enum.filter headers, fn({k, _v}) -> k == :'x-real-ip' end
    Lager.debug "[handler.socket/sockjs_init] peer ip address: ~p", [ip_address]
    peer_info = new peer: self, ip_address: ip_address
    {:ok, peer_info}
  end

  def sockjs_handle(connection, json, peer_info) do
    Lager.debug "[handler.socket/sockjs_handle] peer info: ~p", [peer_info]
    try do
      list = :jsx.decode json
      action = :proplists.get_value "action", list
      true = action != :undefined
      Lager.debug "[handler.socket/sockjs_handle] request action: ~p", [action]
      do_handle connection, action, list, peer_info
    rescue
      _whatever ->
        Lager.debug "[handler.socket/sockjs_handle] bad request"
        body = response_body "error", "bad.request"
        connection.send body
        {:ok, peer_info}
    end
  end

  defp do_handle(connection, "add_peer", list, peer_info) do
    case peer_info.peer_id do
      nil ->
        handle_add_peer connection, list, peer_info
      peer_id ->
        body = response_body "ok", "peer.id", peer_id
        connection.send body
        {:ok, peer_info}
    end
  end

  defp do_handle(_connection, "remove_peer", _list, peer_info) do
    case peer_info.peer_id do
      nil ->
        {:ok, peer_info}
      _peer_id ->
        peer_info = Peer.remove peer_info
        {:ok, peer_info}
    end
  end

  defp do_handle(connection, "list_peers", list, peer_info) do
    scope = :proplists.get_value "scope", list, "all"
    true = scope in ["all", "global", "local"]
    result = Peer.list(peer_info, scope)
    peers = Enum.map result, fn (p) -> p.peer_id end
    body = response_body "ok", "peer.list", peers
    connection.send body
    {:ok, peer_info}
  end

  defp do_handle(connection, "signal_peer", list, peer_info) do
    {:ok, peer_info} = case peer_info.peer_id do
      nil ->
        handle_add_peer connection, list, peer_info
      _peer_id ->
        {:ok, peer_info}
    end
    remote_id = :proplists.get_value "peer_id", list
    true = remote_id != :undefined
    data = :proplists.get_value "data", list
    true = data != :undefined
    Peer.signal(peer_info, remote_id, data)
    {:ok, peer_info}
  end

  defp do_handle(connection, action, _list, peer_info) do
    body = response_body "error", "unsupported.action", action
    connection.send body
    {:ok, peer_info}
  end

  defp handle_add_peer(connection, list, peer_info) do
    scope = :proplists.get_value "scope", list, "global"
    true = scope in ["gloabl", "local"]
    peer_info = Peer.add peer_info, scope
    body = response_body "ok", "peer.id", peer_info.peer_id
    connection.send body
    {:ok, peer_info}
  end

  def sockjs_info(connection, {:signal, remote_id, data}, peer_info) do
    body = response_body "new", "signal", [
      peer_id: remote_id,
      data: data
    ]
    connection.send body
    {:ok, peer_info}
  end

  def sockjs_info(_connection, _info, peer_info) do
    {:ok, peer_info}
  end

  def sockjs_terminate(_connection, peer_info) do
    {:ok, peer_info}
  end

  defp response_body(status, info, data \\ :null) do
    response = [
      status: status,
      info: info,
      data: data
    ]
    response = Enum.filter response, fn({_k, v}) -> v != :null end
    :jsx.encode response
  end
end

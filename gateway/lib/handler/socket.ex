defmodule Handler.Socket do
  import Model.Record
  require Lager
  @bahaviour :sockjs_service

  fields socket: nil,
         ip_address: nil,
         peer_id: nil

  def sockjs_init(connection, _state) do
    [{:headers, headers}] = Enum.filter connection.info, fn({k, _v}) -> k == :headers end
    [{:'x-real-ip', ip_address}] = Enum.filter headers, fn({k, _v}) -> k == :'x-real-ip' end
    Lager.debug "[handler.socket/sockjs_init] peer ip address: ~p", [ip_address]
    peer_info = new socket: self, ip_address: ip_address
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

  defp do_handle(connection, action, _list, peer_info) do
    body = response_body "error", "unsupported.action", action
    connection.send body
    {:ok, peer_info}
  end

  defp handle_add_peer(_connection, _list, peer_info) do
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

defmodule Peer.Worker do
  alias Cache.Distributed, as: Cache
  alias Peer.Pool, as: Peer
  import Model.Record
  require Lager
  use GenServer
  @behaviour :poolboy_worker

  fields peer_id: nil,
         peer: nil,
         peer_ref: nil

  # poolboy callback
  def start_link([]) do
    GenServer.start_link __MODULE__, [], []
  end
  
  # GenServer callbacks
  def handle_call({:add_peer, peer_info, scope}, _from, state) do
    peer_ref = :erlang.monitor :process, peer_info.peer
    key = case scope do
      "local" -> {:peer, peer_info.ip_address}
      "global" -> {:peer, :global}
    end
    value = new peer_id: Utility.random_id, peer: peer_info.peer, peer_ref: peer_ref
    Lager.debug "[peer.worker/handle_call] peer value: ~p", [value]
    result = Cache.get key
    case result do
      nil ->
        Cache.put key, [value]
      values ->
        Cache.put key, [value | values]
    end
    peer_info = peer_info.update peer_id: value.peer_id, peer_scope: scope, peer_ref: peer_ref
    Cache.put {:peer_info, peer_info.peer}, peer_info
    Peer.notify peer_info, "hi"
    {:reply, peer_info, state}
  end

  def handle_cast({:remove_peer, peer_info}, state) do
    key = {:peer, peer_info.ip_address}
    result = Cache.get key
    case result do
      nil ->
        nil
      values ->
        filtrated = Enum.filter values, fn (v) -> v.peer != peer_info.peer end
        Lager.debug "[peer.worker/handle_cast] filtrated peers: ~p", [filtrated]
        Cache.put key, filtrated
        :erlang.demonitor peer_info.peer_ref
    end
    Cache.remove {:peer_info, peer_info.peer}
    Peer.notify peer_info, "bye"
    {:noreply, state}
  end

  def handle_info({:'DOWN', peer_ref, _, peer, _}, state) do
    Lager.debug "[peer.worker/handle_info] peer ~p lost connection", [peer]
    :erlang.demonitor peer_ref
    result = Cache.get {:peer_info, peer}
    case result do
      nil ->
        nil
      peer_info ->
        Cache.remove {:peer_info, peer}
        key = case peer_info.peer_scope do
          "global" -> {:peer, :global}
          "local" -> {:peer, peer_info.ip_address}
        end
        result = Cache.get key
        case result do
          nil ->
            nil
          values ->
            filtrated = Enum.filter values, fn (v) -> v.peer != peer end
            Lager.debug "[peer.worker/handle_info] filtrated peers: ~p", [filtrated]
            Cache.put key, filtrated
        end
        Peer.notify peer_info, "bye"
    end
    {:noreply, state}
  end
end

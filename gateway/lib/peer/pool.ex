defmodule Peer.Pool do
  alias Cache.Distributed, as: Cache
  require Lager
  use Supervisor
  @pool :peer_pool

  # Supervisor callback
  def init([]) do
    pool_specs = Application.get_env(:peerfs_gateway, @pool)
    worker = Peer.Worker
    children = [
      :poolboy.child_spec(@pool, [name: {:local, @pool}, worker_module: worker] ++ pool_specs, [])
    ]
    supervise children, strategy: :one_for_one, max_restarts: 10, max_seconds: 10
  end

  # api
  def start_link() do
    Supervisor.start_link __MODULE__, [], [name: __MODULE__]
  end

  def add(peer_info, scope) do
    :poolboy.transaction(@pool, fn(worker) -> GenServer.call(worker, {:add_peer, peer_info, scope}) end)
  end

  def remove(peer_info) do
    :poolboy.transaction(@pool, fn(worker) -> GenServer.cast(worker, {:remove_peer, peer_info}) end)
    peer_info.update peer_id: nil, peer_scope: nil, peer_ref: nil
  end

  def list(peer_info, scope) do
    peers = case scope do
      "all" -> Cache.get({:peer, peer_info.ip_address}, []) ++ Cache.get({:peer, :global}, [])
      "global" -> Cache.get {:peer, :global}, []
      "local" -> Cache.get {:peer, peer_info.ip_address}, []
    end
    Enum.filter peers, fn (p) -> p.peer != peer_info.peer end
  end

  def signal(peer_info, remote_id, data) do
    peers = Cache.get {:peer, peer_info.ip_address}, []
    result = Enum.filter peers, fn (p) -> p.peer_id == remote_id end
    case result do
      [] -> :ok
      [r] -> send r.peer, {:signal, peer_info.peer_id, data}
    end
  end
end

defmodule PeerFSGateway do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    cowboy = Application.get_env(:peerfs_gateway, :cowboy)
    domain = cowboy[:domain]
    port = cowboy[:port]

    sockjs = :sockjs_handler.init_state("/api/v1/sockjs", Handler.Socket, :sockjs_interface, [])
    websocket = :sockjs_handler.init_state("/api/v1", Handler.Socket, :websocket_interface, [])

    dispatch = :cowboy_router.compile([
      {domain, [
        {"/assets/[...]", :cowboy_static, {
          :priv_dir, :peerfs_gateway, "assets", [{:mimetypes, :cow_mimetypes, :all}]
        }},
        {"/api/v1/sockjs/[...]", :sockjs_cowboy_handler, sockjs},
        {"/api/v1/websocket", :sockjs_cowboy_handler, websocket}
      ]}
    ])

    cowboy_args = [:http, 8,
      [{:port, port}],
      [{:env, [{:dispatch, dispatch}]}]
    ]

    children = [
      supervisor(:cowboy, cowboy_args, function: :start_http)
    ]

    opts = [strategy: :one_for_one, name: PeerFSGateway.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

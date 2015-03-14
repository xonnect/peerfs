defmodule Handler.Socket do
  require Lager
  @bahaviour :sockjs_service

  def sockjs_init(_connection, state) do
    {:ok, state}
  end

  def sockjs_handle(_connection, _request, state) do
    {:ok, state}
  end

  def sockjs_info(_connection, _info, state) do
    {:ok, state}
  end

  def sockjs_terminate(_connection, state) do
    {:ok, state}
  end
end

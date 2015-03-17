defmodule Utility do
  require Lager
  @base 62167219200 # :calendar.datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}})

  def timestamp() do
    {mega_seconds, seconds, _} = :erlang.now
    mega_seconds * 1000_000 + seconds
  end

  def timestamp_us() do
    {mega_seconds, seconds, micro_seconds} = :erlang.now
    mega_seconds * 1000_000_000000 + seconds * 1000000 + micro_seconds
  end

  def timestamp_ms() do
    div timestamp_us, 1000
  end

  def random_id() do
    :crypto.hash(:sha, :uuid.get_v4)
    |> Base.encode16 |> String.downcase
  end
end

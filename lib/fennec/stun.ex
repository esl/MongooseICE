defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Jerboa.Format

  @spec process_message!(binary, Fennec.ip, Fennec.portn) :: binary | no_return
  def process_message!(data, ip, port) do
    {:ok, x} = Format.decode(data)
    y = Fennec.Evaluator.service(x, %{address: ip, port: port})
    Format.encode(y)
  end
end

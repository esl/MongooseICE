defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Jerboa.Params

  @spec process_message!(binary, Fennec.ip, Fennec.portn) :: binary | no_return
  def process_message!(data, ip, port) do
    {:ok, x = %Params{method: :binding}} = Jerboa.Format.decode(data)
    case Fennec.Evaluator.service(x, %{address: ip, port: port}) do
      :void ->
        :void
      y when is_map(y) ->
        Jerboa.Format.encode(y)
    end
  end
end

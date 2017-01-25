defmodule Fennec.STUN do
  @moduledoc false
  # Processing of STUN messages

  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress

  @spec process_message!(binary, Fennec.ip, Fennec.portn) :: binary | no_return
  def process_message!(data, ip, port) do
    params = Format.decode!(data)
    cond do
      binding_req?(params) ->
        binding_response(params, ip, port)
      true ->
        raise "Unprocessable STUN message"
    end
  end

  defp binding_req?(%{class: :request, method: :binding}), do: true
  defp binding_req?(_), do: false

  defp binding_response(params, ip, port) do
    xor_mapped_address = build_xor_mapped_address(ip, port)
    %Format{
      class: :success,
      method: :binding,
      identifier: params.identifier,
      attributes: [xor_mapped_address],
    } |> Format.encode()
  end

  defp build_xor_mapped_address({_, _, _ ,_} = ip4, port) do
    %XORMappedAddress{
      family: :ipv4,
      address: ip4,
      port: port
    }
  end
  defp build_xor_mapped_address(ip6, port) do
    %XORMappedAddress{
      family: :ipv6,
      address: ip6,
      port: port
    }
  end
end

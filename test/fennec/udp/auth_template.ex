defmodule Fennec.UDP.AuthTemplate do
  use ExUnit.Case

  defmacro __using__(_opts) do
    quote do
      import unquote __MODULE__

      @max_value_bytes 763 - 1
      @max_value_chars 128 - 1
      @valid_secret "abc"
      @invalid_secret "abcd"
    end
  end

  defmacro test_auth_for(request, base_attrs) do
    request_str = Atom.to_string(request)
    params_fun = String.to_atom(~s"#{request}_params")
    quote do
      alias Helper.UDP
      alias Jerboa.Params
      alias Jerboa.Format
      alias Jerboa.Format.Body.Attribute.{Username, ErrorCode,
                                          RequestedTransport, Nonce, Realm}

      describe unquote(request_str) <> " request" do
        setup do
          Application.put_env(:fennec, :secret, @valid_secret)
          udp =
            UDP.connect({0, 0, 0, 0, 0, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}, 1)
          on_exit fn ->
            UDP.close(udp)
          end

          username = "bob"
          unquote(
            case request do
              :allocate   -> nil
              _           ->
                quote do
                  UDP.allocate(udp, username)
                end
            end
          )
          {:ok, [udp: udp, username: username]}
        end

        test "without auth attributes returns nonce and realm", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs))
            |> Format.encode()
          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 401} = Params.get_attr(params, ErrorCode)
          assert %Nonce{value: nonce} = Params.get_attr(params, Nonce)
          assert %Realm{value: realm} = Params.get_attr(params, Realm)

          assert String.length(nonce) > 0
          assert String.length(nonce) <= @max_value_chars
          assert byte_size(nonce) <= @max_value_bytes

          assert String.length(realm) > 0
          assert String.length(realm) <= @max_value_chars
          assert byte_size(realm) <= @max_value_bytes
        end

        test "request with all missing attributes fails to authenticate", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs))
            |> Format.encode(secret: @valid_secret, realm: "realm", username: ctx.username)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
        end

        test "request with missing nonce attribute fails to authenticate", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          attrs = [
            %Realm{value: "localhost"},
            %Username{value: ctx.username}
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @valid_secret)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
        end

        test "request with missing username attributes fails to authenticate", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          attrs = [
            %Realm{value: "localhost"},
            %Nonce{value: "nonce"}
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @valid_secret, username: ctx.username)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
        end

        test "request with missing realm attributes fails to authenticate", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          attrs = [
            %Username{value: ctx.username}
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @valid_secret, realm: "localhost")

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 400} = Params.get_attr(params, ErrorCode)
        end

        test "request with invalid secret fails to authenticate", ctx do
          udp = ctx.udp
          nonce_attr = get_nonce(udp)
          id = Params.generate_id()
          attrs = [
            %Username{value: ctx.username},
            %Realm{value: "localhost"},
            nonce_attr
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @invalid_secret)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 401} = Params.get_attr(params, ErrorCode)
        end

        test "request with no message integrity fails to authenticate", ctx do
          udp = ctx.udp
          nonce_attr = get_nonce(udp)
          id = Params.generate_id()
          attrs = [
            %Username{value: ctx.username},
            %Realm{value: "localhost"},
            nonce_attr
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode()

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 401} = Params.get_attr(params, ErrorCode)
        end

        test "request with invalid nonce fails to authenticate", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          attrs = [
            %Username{value: ctx.username},
            %Realm{value: "localhost"},
            %Nonce{value: "some_invalid_nonce...hopefully"}
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @valid_secret)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id} = params

          assert %ErrorCode{code: 438} = Params.get_attr(params, ErrorCode)
          assert %Nonce{value: nonce} = Params.get_attr(params, Nonce)
          assert %Realm{value: realm} = Params.get_attr(params, Realm)

          assert String.length(nonce) > 0
          assert String.length(nonce) <= @max_value_chars
          assert byte_size(nonce) <= @max_value_bytes

          assert String.length(realm) > 0
          assert String.length(realm) <= @max_value_chars
          assert byte_size(realm) <= @max_value_bytes
        end

        test "request with valid nonce authenticate successfully", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          nonce_attr = get_nonce(udp)
          attrs = [
            %Username{value: ctx.username},
            %Realm{value: "localhost"},
            nonce_attr
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @valid_secret)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :success,
                         method: unquote(request),
                         identifier: ^id} = params
        end

        unquote(
          case request do
            :allocate ->
              quote do
                @tag :skip
              end
            _ ->
              nil
          end
        )
        test "request with different username fails to authorize", ctx do
          udp = ctx.udp
          id = Params.generate_id()
          nonce_attr = get_nonce(udp)
          attrs = [
            %Username{value: ctx.username <> "_ish"},
            %Realm{value: "localhost"},
            nonce_attr
          ]
          req =
            UDP. unquote(params_fun)(id, unquote(base_attrs) ++ attrs)
            |> Format.encode(secret: @valid_secret)

          resp = communicate(udp, 0, req)

          params = Format.decode!(resp)
          assert %Params{class: :failure,
                         method: unquote(request),
                         identifier: ^id,
                         attributes: attrs} = params
          assert %ErrorCode{code: 441} = Params.get_attr(params, ErrorCode)
        end
      end

      defp communicate(udp, client_id, req) do
        :ok = UDP.send(udp, client_id, req)
        UDP.recv(udp, client_id)
      end

      defp get_nonce(udp) do
        id = Params.generate_id()
        req = UDP.allocate_request(id)
        resp = communicate(udp, 0, req)
        Params.get_attr(Format.decode!(resp), Nonce)
      end
    end
  end
end

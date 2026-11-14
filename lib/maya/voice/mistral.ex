defmodule Maya.Voice.Mistral do
  @moduledoc false
  # Shared Req client for the Mistral audio API. The key comes from config/runtime.exs.

  def new(timeout_key) do
    mistral = Application.fetch_env!(:maya, :mistral)

    case mistral[:api_key] do
      key when is_binary(key) and key != "" ->
        {:ok,
         Req.new(
           [
             base_url: mistral[:base_url],
             auth: {:bearer, key},
             receive_timeout: voice(timeout_key)
           ] ++ mistral[:req_options]
         )}

      _ ->
        {:error, :no_api_key}
    end
  end

  def voice(key), do: Application.fetch_env!(:maya, :voice)[key]
end

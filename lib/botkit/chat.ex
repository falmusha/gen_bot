defmodule BotKit.Chat do
  @enforce_keys [:data, :options]
  defstruct [
    :module,
    :data,
    :to,
    :reply_pid,
    :timeout,
    :prev_state,
    :options,
    confused_count: 0,
    replies: []
  ]

  def get_data(%__MODULE__{data: data}), do: data

  def put_data(%__MODULE__{} = chat, new_data), do: %{chat | data: new_data}

  def goto(%__MODULE__{} = chat, to), do: %{chat | to: to}

  def reply_with(%__MODULE__{replies: replies} = chat, reply) when is_list(reply) do
    %{chat | replies: [reply ++ replies]}
  end

  def reply_with(%__MODULE__{replies: replies} = chat, reply) when is_binary(reply) do
    %{chat | replies: [reply | replies]}
  end

  def reset_confused_count(%__MODULE__{} = chat), do: %{chat | confused_count: 0}
end

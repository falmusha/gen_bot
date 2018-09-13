defmodule BotKit.Chat do
  @enforce_keys [:data, :options]
  defstruct [
    :module,
    :data,
    :to,
    :event,
    :reply_pid,
    :timeout,
    :prev_state,
    :options,
    :pending,
    confused_count: 0,
    replies: []
  ]

  def get_data(%__MODULE__{data: data}), do: data

  def put_data(%__MODULE__{} = chat, new_data), do: %{chat | data: new_data}

  def goto(%__MODULE__{} = chat, to, options \\ []), do: do_goto(chat, to, options)

  def prev_state(%__MODULE__{prev_state: it}), do: it

  def continue(%__MODULE__{pending: %{wait: true} = pending} = chat),
    do: %{chat | pending: %{pending | wait: false}}

  def reply_with(%__MODULE__{replies: replies} = chat, reply) when is_list(reply) do
    %{chat | replies: [reply ++ replies]}
  end

  def reply_with(%__MODULE__{replies: replies} = chat, reply) when is_binary(reply) do
    %{chat | replies: [reply | replies]}
  end

  def reset_confused_count(%__MODULE__{} = chat), do: %{chat | confused_count: 0}

  defp do_goto(%__MODULE__{} = chat, to, []), do: %{chat | to: to}

  defp do_goto(%__MODULE__{replies: replies} = chat, to, options) do
    case Keyword.get(options, :inject) do
      nil ->
        %{chat | to: to, pending: nil}

      state ->
        pending = %{to: to, wait: true, replies: replies}
        %{chat | to: state, replies: [], pending: pending}
    end
  end
end

defmodule GenBot.Bot do
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

  def put_data(%__MODULE__{} = bot, new_data), do: %{bot | data: new_data}

  def goto(%__MODULE__{} = bot, to, options \\ []), do: do_goto(bot, to, options)

  def prev_state(%__MODULE__{prev_state: it}), do: it

  def continue(%__MODULE__{pending: %{wait: true} = pending} = bot),
    do: %{bot | pending: %{pending | wait: false}}

  def reply_with(%__MODULE__{replies: replies} = bot, reply) when is_list(reply) do
    %{bot | replies: [reply ++ replies]}
  end

  def reply_with(%__MODULE__{replies: replies} = bot, reply) when is_binary(reply) do
    %{bot | replies: [reply | replies]}
  end

  def reset_confused_count(%__MODULE__{} = bot), do: %{bot | confused_count: 0}

  defp do_goto(%__MODULE__{} = bot, to, []), do: %{bot | to: to}

  defp do_goto(%__MODULE__{replies: replies} = bot, to, options) do
    case Keyword.get(options, :inject) do
      nil ->
        %{bot | to: to, pending: nil}

      state ->
        pending = %{to: to, wait: true, replies: replies}
        %{bot | to: state, replies: [], pending: pending}
    end
  end
end

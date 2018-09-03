defmodule BotKit.Bot do
  alias BotKit.Chat

  @behaviour :gen_statem

  @callback init(args :: term) ::
              {:ok, data}
              | {:stop, reason :: any}
            when data: any

  @callback pipeline(String.t()) :: term

  def start_link(module, args, options \\ []) do
    options = process_options(module, options)

    case module.init(args) do
      {:ok, pdata} -> :gen_statem.start_link(__MODULE__, {module, {pdata, options}}, [])
    end
  end

  def callback_mode, do: [:handle_event_function, :state_enter]

  def init({module, {pdata, options}}) do
    chat = %Chat{module: module, data: pdata, prev_state: :__dormant__, options: options}
    {:ok, :__dormant__, chat}
  end

  def begin_chat(pid) do
    :gen_statem.call(pid, :begin)
  end

  def say(pid, text) do
    :gen_statem.call(pid, {:say, text})
  end

  def handle_event(:enter, :__dormant__, :__dormant__, _chat) do
    :keep_state_and_data
  end

  def handle_event(:enter, _old_state, state, %Chat{} = chat) do
    state_module = get_state_module(chat, state)

    chat
    |> state_module.enter()
    |> convert(state)
  end

  def handle_event({:call, from}, :begin, :__dormant__, chat) do
    next = Keyword.get(chat.options, :states) |> hd |> elem(0)
    chat = %{chat | reply_pid: from}
    {:next_state, next, chat}
  end

  def handle_event({:call, from}, {:say, text}, :__dormant__, chat) do
    next = Keyword.get(chat.options, :states) |> hd |> elem(0)
    chat = %{chat | reply_pid: from}
    {:next_state, next, chat, {:next_event, {:call, from}, {:say, text}}}
  end

  def handle_event({:call, from}, {:say, text}, state, chat) do
    state_module = get_state_module(chat, state)
    chat = %{chat | reply_pid: from}

    detections =
      if single_state?(chat) or not state_pipeline?(state_module) do
        chat.module.pipeline(text)
      else
        state_module.state_pipeline(text)
      end

    try do
      chat
      |> state_module.on(detections)
      |> reset_confused_count()
      |> convert(state)
    rescue
      e in [FunctionClauseError] ->
        case e do
          %FunctionClauseError{function: :on, arity: 2} ->
            chat = increment_confused_count(chat)

            if function_exported?(state_module, :confused, 3) do
              chat
              |> state_module.confused(chat.confused_count, detections)
              |> convert(state)
            else
              raise(e)
            end

          it ->
            raise(it)
        end
    end
  end

  defp process_options(module, options) do
    states =
      if Keyword.has_key?(options, :states) do
        options
        |> Keyword.get(:states)
        |> Enum.map(fn it ->
          case it do
            {_state, {_module, state_options}} = pair when is_list(state_options) -> pair
            {state, module} -> {state, {module, []}}
          end
        end)
      else
        [__single__: {module, []}]
      end

    Keyword.put(options, :states, states)
  end

  defp get_state_module(chat, state),
    do: chat.options |> Keyword.get(:states) |> Keyword.get(state) |> elem(0)

  defp single_state?(%Chat{options: [states: states]}) when length(states) > 1, do: false
  defp single_state?(_), do: true

  defp state_pipeline?(state_module),
    do: function_exported?(state_module, :state_pipeline, 1)

  defp convert(%Chat{} = chat, state) do
    actions = []

    case chat.to do
      nil ->
        actions = put_reply(actions, chat)
        chat = %{chat | replies: [], to: nil, reply_pid: nil}
        {:keep_state, chat, actions}

      ^state ->
        chat = %{chat | to: nil, prev_state: state}
        {:repeat_state, chat, actions}

      next ->
        chat = %{chat | to: nil, prev_state: state}
        {:next_state, next, chat, actions}
    end
  end

  defp put_reply(actions, %Chat{replies: [], reply_pid: from}) do
    [{:reply, from, nil} | actions]
  end

  defp put_reply(actions, %Chat{replies: replies, reply_pid: from}) do
    if length(replies) == 1 do
      [{:reply, from, hd(replies)} | actions]
    else
      [{:reply, from, Enum.reverse(replies)} | actions]
    end
  end

  defp increment_confused_count(%Chat{confused_count: count} = chat),
    do: %{chat | confused_count: count + 1}

  defp reset_confused_count(%Chat{} = chat), do: %{chat | confused_count: 0}
end

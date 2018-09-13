defmodule BotKit.Bot do
  alias BotKit.Chat

  @behaviour :gen_statem

  @callback init(args :: term) ::
              {:ok, data}
              | {:stop, reason :: any}
            when data: any

  @callback pipeline(String.t()) :: term

  @callback reply(Chat.t(), String.t()) :: term

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

  def begin(pid), do: :gen_statem.call(pid, :begin)

  def begin_async(pid), do: :gen_statem.cast(pid, :begin)

  def send(pid, text), do: :gen_statem.call(pid, {:say, text})

  def send_async(pid, text), do: :gen_statem.cast(pid, {:say, text})

  def handle_event(:enter, :__dormant__, :__dormant__, _chat), do: :keep_state_and_data

  def handle_event(:enter, _old_state, state, %Chat{} = chat) do
    chat = %{chat | event: :enter}
    state_module = get_state_module(chat, state)

    if function_exported?(state_module, :enter, 1) do
      chat
      |> state_module.enter()
      |> convert(state)
    else
      convert(chat, state)
    end
  end

  def handle_event(:timeout, {:next, next}, state, chat) do
    convert(%{chat | event: :timeout, to: next}, state)
  end

  def handle_event(event_type, :begin, :__dormant__, chat) do
    chat =
      case event_type do
        {:call, from} -> %{chat | event: :call, reply_pid: from}
        :cast -> %{chat | event: :cast, reply_pid: nil}
      end

    {:next_state, Keyword.get(chat.options, :states) |> hd |> elem(0), chat}
  end

  def handle_event({:call, from}, {:say, text}, state, chat) do
    handle_say(text, state, %{chat | event: :call, reply_pid: from})
  end

  def handle_event(:cast, {:say, text}, state, chat) do
    handle_say(text, state, %{chat | event: :cast, reply_pid: nil})
  end

  defp handle_say(text, :__dormant__, chat) do
    next = Keyword.get(chat.options, :states) |> hd |> elem(0)
    {:next_state, next, chat, {:next_event, :cast, {:say, text}}}
  end

  defp handle_say(text, state, chat) do
    state_module = get_state_module(chat, state)

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
            {_state, {_module, state_options}} = pair when is_list(state_options) ->
              {:module, _} = Code.ensure_loaded(module)
              pair

            {state, module} ->
              {:module, _} = Code.ensure_loaded(module)
              {state, {module, []}}
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

  defp convert(%Chat{pending: %{to: to, wait: false, replies: replies}} = chat, state) do
    convert(%{chat | pending: nil, to: to, replies: chat.replies ++ replies}, state)
  end

  defp convert(%Chat{to: to, event: event} = chat, state) do
    actions = []

    case {to, event} do
      {nil, _} ->
        actions = put_reply(actions, chat)
        chat = %{chat | replies: [], to: nil, reply_pid: nil}
        {:keep_state, chat, actions}

      {^state, _} ->
        chat = %{chat | to: nil, prev_state: state}
        {:repeat_state, chat, actions}

      {next, :enter} ->
        actions = actions ++ [{:timeout, 1, {:next, next}}]
        chat = %{chat | to: nil, prev_state: state}
        {:keep_state, chat, actions}

      {next, _} ->
        chat = %{chat | to: nil, prev_state: state}
        {:next_state, next, chat, actions}
    end
  end

  defp put_reply(actions, %Chat{reply_pid: nil, replies: replies, module: module} = chat) do
    case replies do
      [] -> :ok
      [reply] -> module.reply(chat, reply)
      it -> module.reply(chat, Enum.reverse(it))
    end

    actions
  end

  defp put_reply(actions, %Chat{reply_pid: from, replies: replies}) do
    reply =
      case replies do
        [] -> nil
        [it] -> it
        it -> Enum.reverse(it)
      end

    [{:reply, from, reply} | actions]
  end

  defp increment_confused_count(%Chat{confused_count: count} = chat),
    do: %{chat | confused_count: count + 1}

  defp reset_confused_count(%Chat{} = chat), do: %{chat | confused_count: 0}
end

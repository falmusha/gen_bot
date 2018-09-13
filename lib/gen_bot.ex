defmodule GenBot do
  alias GenBot.Bot

  @behaviour :gen_statem

  @callback init(args :: term) ::
              {:ok, data}
              | {:stop, reason :: any}
            when data: any

  @callback pipeline(String.t()) :: term

  @callback reply(Bot.t(), String.t()) :: term

  def start_link(module, args, options \\ []) do
    options = process_options(module, options)

    case module.init(args) do
      {:ok, pdata} -> :gen_statem.start_link(__MODULE__, {module, {pdata, options}}, [])
    end
  end

  def callback_mode, do: [:handle_event_function, :state_enter]

  def init({module, {pdata, options}}) do
    bot = %Bot{module: module, data: pdata, prev_state: :__dormant__, options: options}
    {:ok, :__dormant__, bot}
  end

  def begin(pid), do: :gen_statem.call(pid, :begin)

  def begin_async(pid), do: :gen_statem.cast(pid, :begin)

  def send(pid, text), do: :gen_statem.call(pid, {:say, text})

  def send_async(pid, text), do: :gen_statem.cast(pid, {:say, text})

  def handle_event(:enter, :__dormant__, :__dormant__, _bot), do: :keep_state_and_data

  def handle_event(:enter, _old_state, state, %Bot{} = bot) do
    bot = %{bot | event: :enter}
    state_module = get_state_module(bot, state)

    if function_exported?(state_module, :enter, 1) do
      bot
      |> state_module.enter()
      |> convert(state)
    else
      convert(bot, state)
    end
  end

  def handle_event(:timeout, {:next, next}, state, bot) do
    convert(%{bot | event: :timeout, to: next}, state)
  end

  def handle_event(event_type, :begin, :__dormant__, bot) do
    bot =
      case event_type do
        {:call, from} -> %{bot | event: :call, reply_pid: from}
        :cast -> %{bot | event: :cast, reply_pid: nil}
      end

    {:next_state, Keyword.get(bot.options, :states) |> hd |> elem(0), bot}
  end

  def handle_event({:call, from}, {:say, text}, state, bot) do
    handle_say(text, state, %{bot | event: :call, reply_pid: from})
  end

  def handle_event(:cast, {:say, text}, state, bot) do
    handle_say(text, state, %{bot | event: :cast, reply_pid: nil})
  end

  defp handle_say(text, :__dormant__, bot) do
    next = Keyword.get(bot.options, :states) |> hd |> elem(0)
    {:next_state, next, bot, {:next_event, :cast, {:say, text}}}
  end

  defp handle_say(text, state, bot) do
    state_module = get_state_module(bot, state)

    detections =
      if single_state?(bot) or not state_pipeline?(state_module) do
        bot.module.pipeline(text)
      else
        state_module.state_pipeline(text)
      end

    try do
      bot
      |> state_module.on(detections)
      |> reset_confused_count()
      |> convert(state)
    rescue
      e in [FunctionClauseError] ->
        case e do
          %FunctionClauseError{function: :on, arity: 2} ->
            bot = increment_confused_count(bot)

            if function_exported?(state_module, :confused, 3) do
              bot
              |> state_module.confused(bot.confused_count, detections)
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

  defp get_state_module(bot, state),
    do: bot.options |> Keyword.get(:states) |> Keyword.get(state) |> elem(0)

  defp single_state?(%Bot{options: [states: states]}) when length(states) > 1, do: false
  defp single_state?(_), do: true

  defp state_pipeline?(state_module),
    do: function_exported?(state_module, :state_pipeline, 1)

  defp convert(%Bot{pending: %{to: to, wait: false, replies: replies}} = bot, state) do
    convert(%{bot | pending: nil, to: to, replies: bot.replies ++ replies}, state)
  end

  defp convert(%Bot{to: to, event: event} = bot, state) do
    actions = []

    case {to, event} do
      {nil, _} ->
        actions = put_reply(actions, bot)
        bot = %{bot | replies: [], to: nil, reply_pid: nil}
        {:keep_state, bot, actions}

      {^state, _} ->
        bot = %{bot | to: nil, prev_state: state}
        {:repeat_state, bot, actions}

      {next, :enter} ->
        actions = actions ++ [{:timeout, 1, {:next, next}}]
        bot = %{bot | to: nil, prev_state: state}
        {:keep_state, bot, actions}

      {next, _} ->
        bot = %{bot | to: nil, prev_state: state}
        {:next_state, next, bot, actions}
    end
  end

  defp put_reply(actions, %Bot{reply_pid: nil, replies: replies, module: module} = bot) do
    case replies do
      [] -> :ok
      [reply] -> module.reply(bot, reply)
      it -> module.reply(bot, Enum.reverse(it))
    end

    actions
  end

  defp put_reply(actions, %Bot{reply_pid: from, replies: replies}) do
    reply =
      case replies do
        [] -> nil
        [it] -> it
        it -> Enum.reverse(it)
      end

    [{:reply, from, reply} | actions]
  end

  defp increment_confused_count(%Bot{confused_count: count} = bot),
    do: %{bot | confused_count: count + 1}

  defp reset_confused_count(%Bot{} = bot), do: %{bot | confused_count: 0}
end

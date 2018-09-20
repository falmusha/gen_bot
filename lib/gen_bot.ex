defmodule GenBot do
  alias GenBot.Bot

  @behaviour :gen_statem

  @type reason :: :normal | :shutdown | {:shutdown, term} | term

  @callback init(args :: term) ::
              {:ok, data}
              | {:stop, reason :: any}
            when data: any

  @callback pipeline(Bot.t(), String.t()) :: term

  @callback reply(Bot.t(), String.t()) :: term

  @callback handle_info(message :: term, state :: term, Bot.t()) :: Bot.t()

  @callback terminate(reason, state :: term, Bot.t()) :: term

  @optional_callbacks reply: 2, handle_info: 3, terminate: 3

  def start(module, args, options \\ []) do
    :gen_statem.start(__MODULE__, {module, args, options}, [])
  end

  def start_link(module, args, options \\ []) do
    :gen_statem.start_link(__MODULE__, {module, args, options}, [])
  end

  def callback_mode, do: [:handle_event_function, :state_enter]

  def init({module, args, options}) do
    options = process_options(module, options)

    {pdata, initial_state} =
      case module.init(args) do
        {:ok, pdata} -> {pdata, :__dormant__}
        {:ok, pdata, state} -> {pdata, state}
      end

    bot = %Bot{module: module, data: pdata, prev_state: :__dormant__, options: options}

    {:ok, initial_state, bot}
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
        {:call, from} -> %{bot | event: :call, from: from}
        :cast -> %{bot | event: :cast, from: nil}
      end

    {:next_state, Keyword.get(bot.options, :states) |> hd |> elem(0), bot}
  end

  def handle_event(event_type, :begin, _state, _bot) do
    :keep_state_and_data
  end

  def handle_event({:call, from}, {:say, text}, state, bot) do
    handle_say(text, state, %{bot | event: :call, from: from})
  end

  def handle_event(:cast, {:say, text}, state, bot) do
    handle_say(text, state, %{bot | event: :cast, from: nil})
  end

  def handle_event(:info, message, state, %Bot{module: module} = bot) do
    message
    |> module.handle_info(state, %{bot | event: :info})
    |> convert(state)
  end

  def terminate(reason, state, %Bot{module: module} = bot) do
    module.terminate(reason, state, bot)
  end

  def format_status(_opt, [_pdict, state, _data]) do
    state
  end

  defp handle_say(text, :__dormant__, bot) do
    next = Keyword.get(bot.options, :states) |> hd |> elem(0)
    {:next_state, next, bot, {:next_event, :cast, {:say, text}}}
  end

  defp handle_say(text, state, bot) do
    state_module = get_state_module(bot, state)

    detections =
      if single_state?(bot) or not state_pipeline?(state_module) do
        bot.module.pipeline(bot, text)
      else
        state_module.state_pipeline(bot, text)
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

  defp process_options(module, user_opts) do
    defaults = [states: [__single__: {module, []}]]

    defaults
    |> Keyword.merge(user_opts)
    |> Keyword.update!(:states, &process_state_options/1)
  end

  defp process_state_options(states) do
    Enum.map(states, fn it ->
      case it do
        {_state, {module, state_options}} = pair when is_list(state_options) ->
          {:module, _} = Code.ensure_loaded(module)
          pair

        {state, module} ->
          {:module, _} = Code.ensure_loaded(module)
          {state, {module, []}}
      end
    end)
  end

  defp get_state_module(bot, state),
    do: bot.options |> Keyword.get(:states) |> Keyword.get(state) |> elem(0)

  defp single_state?(%Bot{options: [states: states]}) when length(states) > 1, do: false
  defp single_state?(_), do: true

  defp state_pipeline?(state_module),
    do: function_exported?(state_module, :state_pipeline, 1)

  defp convert(
         %Bot{pending: %{to: to, wait: false, replies: replies, handler: handler}} = bot,
         state
       ) do
    bot =
      case handler do
        nil -> %{bot | pending: nil, to: to, replies: replies ++ bot.replies}
        it -> it.(%{bot | pending: nil, to: to, replies: replies ++ bot.replies})
      end

    convert(bot, state)
  end

  defp convert(%Bot{to: to, event: event} = bot, state) do
    case {to, event} do
      {nil, _} ->
        reply = format_reply(bot.replies)

        actions =
          if bot.from do
            [{:reply, bot.from, reply}]
          else
            bot.module.reply(bot, reply)
            []
          end

        {:keep_state, %{bot | replies: [], to: nil, from: nil}, actions}

      {^state, _} ->
        {:repeat_state, %{bot | to: nil, prev_state: state}, []}

      {next, :enter} ->
        {:keep_state, %{bot | to: nil, prev_state: state}, [{:timeout, 1, {:next, next}}]}

      {next, _} ->
        {:next_state, next, %{bot | to: nil, prev_state: state}, []}
    end
  end

  def format_reply(replies) do
    case replies do
      [] -> nil
      [it] -> it
      it -> Enum.reverse(it)
    end
  end

  defp increment_confused_count(%Bot{confused_count: count} = bot),
    do: %{bot | confused_count: count + 1}

  defp reset_confused_count(%Bot{} = bot), do: %{bot | confused_count: 0}
end

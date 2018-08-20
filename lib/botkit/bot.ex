defmodule BotKit.Bot do
  alias BotKit.Chat

  @behaviour :gen_statem

  @callback init(args :: term) ::
              {:ok, data}
              | {:stop, reason :: any}
            when data: any

  @callback pipeline(String.t()) :: term
  @callback config() :: term

  @default_convert_opts [skip_reply: false]

  defmacro __using__([states: states] = _opts) when length(states) > 0 do
    quote do
      @behaviour BotKit.Bot

      def config() do
        [single: false, states: unquote(states)]
      end
    end
  end

  defmacro __using__([]) do
    quote do
      @behaviour BotKit.Bot
      use BotKit.BotState, single: true

      def config() do
        [single: true, states: [__single__: __MODULE__]]
      end
    end
  end

  def start_link(module, args) do
    case module.init(args) do
      {:ok, pdata} -> :gen_statem.start_link(__MODULE__, {module, pdata}, [])
    end
  end

  def callback_mode, do: [:handle_event_function, :state_enter]

  def init({module, pdata}) do
    {:ok, :__dormant__, %Chat{module: module, data: pdata, prev_state: :__dormant__}}
  end

  def say(pid, text) do
    :gen_statem.call(pid, {:say, text})
  end

  def handle_event(:enter, :__dormant__, :__dormant__, _chat) do
    :keep_state_and_data
  end

  def handle_event(:enter, old_state, state, chat) do
    state_module = get_state_module(chat, state)
    chat = state_module.enter(chat)

    if old_state == :__dormant__,
      do: convert(chat, state, skip_reply: true),
      else: convert(chat, state)
  end

  def handle_event({:call, from}, {:say, text}, :__dormant__, chat) do
    next = Keyword.get(chat.module.config(), :states) |> hd |> elem(0)
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

    chat
    |> state_module.on(detections)
    |> convert(state)
  end

  defp get_state_module(chat, state),
    do: chat.module.config() |> Keyword.get(:states) |> Keyword.get(state)

  defp single_state?(chat),
    do: chat.module.config() |> Keyword.get(:states) |> length() == 1

  defp state_pipeline?(state_module),
    do: :erlang.function_exported(state_module, :state_pipeline, 1)

  defp convert(%Chat{} = chat, state, opts \\ @default_convert_opts) do
    actions = []

    case chat.to do
      nil ->
        if Keyword.get(opts, :skip_reply) do
          chat = %{chat | to: nil}
          {:keep_state, chat, actions}
        else
          actions = put_reply(actions, chat)
          chat = %{chat | replies: [], to: nil, reply_pid: nil}
          {:keep_state, chat, actions}
        end

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
end

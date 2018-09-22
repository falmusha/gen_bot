defmodule GenBot do
  alias GenBot.{Bot, Statem}

  @type reason :: :normal | :shutdown | {:shutdown, term} | term

  @type data :: term

  @callback init(args :: term) :: {:ok, data} | {:stop, reason :: any}

  @callback pipeline(Bot.t(), String.t()) :: term

  @callback pre_hook(Bot.t(), String.t()) :: Bot.t()

  @callback post_hook(Bot.t()) :: Bot.t()

  @callback reply(Bot.t(), String.t()) :: term

  @callback handle_info(message :: term, state :: term, Bot.t()) :: Bot.t()

  @callback terminate(reason, state :: term, Bot.t()) :: term

  @optional_callbacks pre_hook: 2, post_hook: 1, reply: 2, handle_info: 3, terminate: 3

  def start(module, args, options \\ []) do
    :gen_statem.start(Statem, {module, args, options}, [])
  end

  def start_link(module, args, options \\ []) do
    :gen_statem.start_link(Statem, {module, args, options}, [])
  end

  def begin(pid), do: :gen_statem.call(pid, :begin)

  def begin_async(pid), do: :gen_statem.cast(pid, :begin)

  def send(pid, text), do: :gen_statem.call(pid, {:say, text})

  def send_async(pid, text), do: :gen_statem.cast(pid, {:say, text})
end

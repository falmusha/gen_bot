defmodule BotKit.Bot do
  @behaviour :gen_statem

  @type state :: {atom, String.t()}
  @type pipeline :: term

  @callback on(term, state, term) :: {:next, state, term} | {:stay, term}
  @callback pipeline(pipeline, String.t()) :: pipeline

  defmacro __using__(opts) do
    quote do
      @behaviour BotKit.Bot

      states_list =
        case Keyword.get(unquote(opts), :states, []) do
          [] -> %{}
          it -> Enum.into(it, %{})
        end

      def states() do
        states_list
      end
    end
  end

  def start_link(module, data) do
    :gen_statem.start_link(__MODULE__, {module, data}, [])
  end

  def callback_mode, do: [:handle_event_function, :state_enter]

  def init({module, data}) do
    states = module.states()
    first_state = states |> hd() |> elem(0)

    statem_data = %{
      module: module,
      state_modules: states,
      user_data: data
    }

    {:ok, first_state, statem_data}
  end

  def say(pid, text) do
    :gen_statem.cast(pid, {:utterence, text})
  end

  def handle_event(:cast, {:utterence, text}, state, statem_data) do
    %{module: module, state_modules: state_modules} = statem_data
    state_module = state_modules[state][:module]

    detections =
      if Module.defines?(state_module, {:pipeline, 1}, :def) do
        state_module.pipeline(text)
      else
        module.pipeline(%{}, text)
      end

    case state_module.on(detections, statem_data[:user_data]) do
      {:stay, user_data} ->
        {:keep_state, %{statem_data | user_data: user_data}}

      {:next, next_state, user_data} ->
        user_data =
          if Module.defines?(state_module, {:exit, 2}, :def) do
            state_module.leave(next_state, user_data)
          else
            user_data
          end

        {:next_state, next_state, %{statem_data | user_data: user_data}}
    end
  end

  def terminate(reason, state, data) do
    data[:module].terminate(reason, state, data)
  end
end

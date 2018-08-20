defmodule BotKit.Chat do
  @enforce_keys [:data]
  defstruct [:module, :data, :to, :reply_pid, :timeout, :prev_state, replies: []]

  def goto(%__MODULE__{} = chat, to), do: %{chat | to: to}

  def put_reply(%__MODULE__{replies: replies} = chat, reply) do
    %{chat | replies: [reply | replies]}
  end

  def put_replies(%__MODULE__{replies: replies} = chat, new_replies) do
    %{chat | replies: [new_replies ++ replies]}
  end
end

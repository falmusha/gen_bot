defmodule GenBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :gen_bot,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mox, "~> 0.3", only: :test}
    ]
  end

  defp description() do
    "Chatbot library with an API around the OTP statem module."
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/falmusha/gen_bot"}
    ]
  end
end

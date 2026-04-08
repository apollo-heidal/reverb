defmodule ReverbDemoApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: ReverbDemoApp.PubSub},
      ReverbDemoApp.Emitter
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ReverbDemoApp.Supervisor)
  end
end

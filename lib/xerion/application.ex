defmodule Xerion.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Load environment variables from .env file
    Dotenv.load()

    children = [
      {Xerion.WebServer, []},
      {Xerion.LexeSidecar, []}
    ]

    opts = [strategy: :one_for_one, name: Xerion.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

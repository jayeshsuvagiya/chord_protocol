defmodule ChordProtocol.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    System.argv() |> parse_args |> process
  end

  @doc """
  'args' can be -h or help.
  Otherwise it is a numofNodes,numofRequests.
  Eg - 1000000 100
  """
  def parse_args(args) do
    parse =
      OptionParser.parse(args,
        strict: [non: :integer, nom: :integer]
      )

    case parse do
      {[help: true], _, _} ->
        :help

      {_, [n, m], _} ->
        {String.to_integer(n),String.to_integer(m)}

      _ ->
        :help
    end
  end

  @doc """
  Actual start of algorithm.
  """
  def process({non, nom}) do
    # List all child processes to be supervised
    children = [
    {ChordProtocol.NetworkSimulator,{non,nom}}
    ]
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GossipSimulator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def process(:help) do
    IO.puts("""
    usage:  mix run --no-halt proj3.exs <n> <m>
    Where n is number of peers.
    m is number of requests each peer has to make.
    """)

    System.halt(0)
  end
end

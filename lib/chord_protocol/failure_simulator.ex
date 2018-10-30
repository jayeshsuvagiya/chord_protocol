defmodule ChordProtocol.FailureSimulator do
  @moduledoc false
  


  use GenServer
  @me FailureSimulator
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: @me)
  end

  def init(non) do
    {:ok, {non,0}}
  end

  def handle_cast(:done, {non,count}) do
    if non==count+1 do
      IO.puts "Intialised..Please Wait"
      GenServer.cast(NetworkSimulator,:start_hop)
    end
    {:noreply, {non,count+1}}
  end

end
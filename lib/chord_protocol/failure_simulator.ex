defmodule ChordProtocol.FailureSimulator do
  @moduledoc false
  


  use GenServer
  @me FailureSimulator
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: @me)
  end

  def init(non) do
    {:ok, {non,0,[]}}
  end

  def handle_cast(:done, {non,count,nodes}) do
    if non==count+1 do
      IO.puts "Intialised..Please Wait"
      GenServer.cast(NetworkSimulator,:start_hop)
      Process.send_after(self(),:kill_node,10000)
    end
    {:noreply, {non,count+1,nodes}}
  end

  def handle_cast({:save,n}, {non,count,nodes}) do
    {:noreply, {non,count,n}}
  end

  def handle_info(:kill_node,{non,count,nodes}) do
    nof=round(non*0.10)
    1..nof |> Enum.each(fn x ->
      peer = Enum.random(nodes)
      GenServer.cast({:global,peer},:die)
    end)
    {:noreply, {non,count,nodes}}
  end

end
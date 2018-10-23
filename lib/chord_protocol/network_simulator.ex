defmodule ChordProtocol.NetworkSimulator do
  use GenServer
  require Logger

  @me NetworkSimulator

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @me)
  end

  def init(args) do
    Process.send_after(self(), :kickoff, 0)
    {:ok, args}
  end



  def handle_info(:kickoff, {non, nom})   do
    #nodes = 1..non |> Enum.map(fn x -> ChordProtocol.Peer.start({"node" <> Integer.to_string(x),Enum.random(nodes)}) end)
    peer = ChordProtocol.Peer.start({"node" <> Integer.to_string(non-1),nil})
    nodes = List.insert_at([],0,peer)
    Process.send_after(self(),{:start_node,non-2},100)
    #nodes = start_node(non-1,nodes)
    Process.send_after(self(),{:start_query},50000)
    #IO.inspect(nodes)
    noh = 0
    dcount = 0
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:start_query},{non,nom,noh,dcount,nodes}) do
    #IO.inspect(nodes)
    1..nom |> Enum.each(fn x ->
      Process.send_after(self(),{:start_msg,x},100)
    end)
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:start_msg,x},{non,nom,noh,dcount,nodes}) do
    msg = "message" <> Integer.to_string(x)
    <<message::big-unsigned-integer-size(160)>> = :crypto.hash(:sha,msg)
    nodes |> Enum.each(fn c ->
      GenServer.call({:global,c},{:find_key,message,0,non})
      #IO.inspect(c)
    end)
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:start_node,n},{non,nom,noh,dcount,nodes}) do
    peer = ChordProtocol.Peer.start({"node" <> Integer.to_string(n),Enum.random(nodes)})
    nodes = List.insert_at(nodes,0,peer)
    if (n>0) do
      Process.send_after(self(),{:start_node,n-1},200)
    end
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_cast({:save_hops,{_n,hops}},{non,nom,noh,dcount,nodes}) do
    noh = noh+hops
    dcount = dcount+1
    #IO.puts("save_hop")
    #IO.inspect({n,hops})
    if(dcount==nom) do
      IO.puts("Average Hop Count")
      IO.inspect(noh/nom)
      System.halt(0)
    end
    {:noreply, {non,nom,noh,dcount,nodes}}
  end



  def start_node(non,nodes) when non>0 do
    peer = ChordProtocol.Peer.start({"node" <> Integer.to_string(non),Enum.random(nodes)})
    nodes = List.insert_at(nodes,0,peer)
    start_node(non-1,nodes)
  end

  def start_node(_non,nodes) do
    nodes
  end

end
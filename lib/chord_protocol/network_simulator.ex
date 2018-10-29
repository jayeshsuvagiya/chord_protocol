defmodule ChordProtocol.NetworkSimulator do
  use GenServer
  require Logger

  @me NetworkSimulator
  @timeo 1000000
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @me)
  end

  def init(args) do
    Process.send_after(self(), :kickoff, 10)
    {:ok, args}
  end



  def handle_info(:kickoff, {non, nom})   do
    #nodes = 1..non |> Enum.map(fn x -> ChordProtocol.Peer.start({"node" <> Integer.to_string(x),Enum.random(nodes)}) end)
    peer = ChordProtocol.Peer.start({"node" <> Integer.to_string(non-1),nil})
    nodes = List.insert_at([],0,peer)
    nodes = start_node(non-2,nodes)
    #Process.send_after(self(),{:start_node,non-2},5000)
    GenServer.cast({:global,peer},{:join_network,nil})
    Process.send_after(self(),{:join_node,non-2},2000)
    Process.send_after(self(),{:start_query},5000*non)
    #IO.inspect(nodes)
    noh = 0
    dcount = 0
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:start_query},{non,nom,noh,dcount,nodes}) do
    IO.inspect(length(nodes))
    1..nom |> Enum.each(fn x ->
      Process.send_after(self(),{:start_msg,x},5*nom*non)
    end)
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:start_msg,x},{non,nom,noh,dcount,nodes}) do
    msg = "message" <> Integer.to_string(x)
    <<message::big-unsigned-integer-size(160)>> = :crypto.hash(:sha,msg)
    nodes |> Enum.with_index |> Enum.each(fn {c,i} ->
      Process.send_after(self(),{:find_key,message,c},100*i)
      #GenServer.call({:global,c},{:find_key,message,0},@timeo)
      #IO.inspect(c)
    end)
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:find_key,message,c},{non,nom,noh,dcount,nodes}) do
    GenServer.call({:global,c},{:find_key,message,0,c},@timeo)
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:start_node,n},{non,nom,noh,dcount,nodes}) do
    peer = ChordProtocol.Peer.start({"node" <> Integer.to_string(n),Enum.random(nodes)})
    nodes = List.insert_at(nodes,0,peer)
    if (n>0) do
      Process.send_after(self(),{:start_node,n-1},0)
    end
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_info({:join_node,n},{non,nom,noh,dcount,nodes}) do
    [a,b]=Enum.slice(nodes,n,2)
    GenServer.cast({:global,a},{:join_network,b})
    if (n>0) do
      Process.send_after(self(),{:join_node,n-1},1000*(non-n))
    end
    {:noreply, {non,nom,noh,dcount,nodes}}
  end

  def handle_cast({:save_hops,{m,s,f,hops}},{non,nom,noh,dcount,nodes}) do
    noh = noh+hops
    dcount = dcount+1
    IO.puts("save_hop")
    IO.inspect({m,s,f,hops})
    if(dcount==nom*non) do
      IO.puts("Average Hop Count")
      IO.inspect(noh/dcount)
    #  System.halt(0)
    end
    {:noreply, {non,nom,noh,dcount,nodes}}
  end



  def start_node(non,nodes) when non>-1 do
    peer = ChordProtocol.Peer.start({"node" <> Integer.to_string(non),Enum.random(nodes)})
    nodes = List.insert_at(nodes,0,peer)
    start_node(non-1,nodes)
  end

  def start_node(_non,nodes) do
    nodes
  end

end
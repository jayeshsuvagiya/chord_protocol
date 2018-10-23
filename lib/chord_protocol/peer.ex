defmodule ChordProtocol.Peer do
  use GenServer, restart: :temporary
  require Logger

  #did no used start_link as it has to purely decentralized peer to peer network.
  def start({identifier,dnode}) do
    #Integer.parse("74E5A4BCAB7355B8CAB7DF73D07747CD85C925E7",16)
    #<<num::big-unsigned-integer-size(160)>> = <<116, 229, 164, 188, 171, 115, 85, 184, 202, 183, 223, 115, 208, 119, 71, 205,133,201,37,231>>
    #b = :crypto.hash(:sha, "node6") |> Base.encode16
    #IO.inspect({identifier,:crypto.hash(:sha,identifier)|> Base.encode16()})
    #IO.inspect(identifier)
    <<identifier::big-unsigned-integer-size(160)>> = :crypto.hash(:sha,identifier)
    #Process.register(pid,:identifier)
    GenServer.start(__MODULE__, {identifier,dnode},name: {:global ,identifier})
    identifier
  end

  def init({identifier,dnode}) do
    #initialise finger start values (n+2^i)mod(2^160)
    finger = 0..159 |> Enum.map(fn x ->
      start = rem(trunc(identifier+ trunc(:math.pow(2,x))),trunc(:math.pow(2,160)))
      #IO.inspect(start)
      {start,identifier}
    end)
    #IO.inspect(finger)


    Process.send_after(self(), {:join,dnode}, 10)
    {:ok, {finger, identifier, nil}}
  end

  def handle_info({:join,dnode},{finger, identifier, _pre}) do
    {p,newfinger} = if (dnode) do
      [{fstart,_} | rest] = finger
     # IO.puts("arb_node")
      #IO.inspect(dnode)
      peer = GenServer.call(globalcall(dnode),{:find_suc,fstart},10000)
      pre =  GenServer.call(globalcall(peer),:get_pre)
      GenServer.call(globalcall(peer),{:set_pre,identifier})
      rest |> Enum.map(fn {start,_} ->
        {start,GenServer.call(globalcall(dnode),{:find_suc,start},10000)}
      end)
      {pre,[{fstart,peer}|rest]}
    else
      rest = finger |> Enum.map(fn {start,_} ->
        {start,identifier}
      end)
      pre = identifier
      {pre,rest}
    end
    #IO.puts("node,pre")
    #IO.inspect({identifier,p})
    #IO.puts("TABLE")
    #IO.inspect(newfinger)
    stabilize()
    fix_fingers(0)
    check_finger()
    { :noreply, {newfinger, identifier, p} }
  end


  def handle_info(:stabilize,{finger, identifier, pre}) do
    [{start,peer}|rest] = finger
    x = if peer==identifier do
      pre
    else
      GenServer.call(globalcall(peer),:get_pre)
    end
    peer = if between(x,identifier,peer) do
      x
      else
      peer
    end
    #if peer!=identifier do
    #GenServer.call(globalcall(peer),{:set_prec,identifier})
    #end
    stabilize()
    { :noreply, {[{start,peer}|rest], identifier, pre} }
  end

  def handle_info({:fix_fingers,n},{finger, identifier, pre}) do
    {s,_pr} = Enum.at(finger,n)
    {_start,suc} = List.first(finger)
    peer = if betweeno(s,identifier,suc) do
      suc
    else
      ndash=closest_prec_node(s,{finger,identifier,pre})
      suc = if ndash==identifier do
        suc
      else
        GenServer.call(globalcall(ndash),{:find_suc,s},10000)
      end
      suc
    end
    newfinger = List.replace_at(finger,n,{s,peer})
    n=n+1
    n = if n>159 do
      1
      else
      n
    end
    fix_fingers(n)
    { :noreply, {newfinger, identifier, pre} }
  end

  def handle_info(:check_finger,{finger, identifier, pre}) do
    #{_start,peer} = List.first(finger)
    #IO.puts("Finger TABLE")
    #IO.inspect({identifier,pre,peer})
    #IO.inspect(Enum.take(finger,1))
    { :noreply, {finger, identifier, pre} }
  end

  def handle_call(:get_pre,_from,{finger,identifier,pre}) do
    #check_finger()
    { :reply, pre,{finger,identifier,pre} }
  end
  def handle_call(:get_suc,_from,{finger,identifier,pre}) do
    {_start,peer} = List.first(finger)
    { :reply,peer,{finger,identifier,pre} }
  end

  def handle_call({:find_suc,id},_from,{finger,identifier,pre}) do
    #IO.puts("test1")
    #IO.inspect(List.first(finger))
    {_start,suc} = List.first(finger)
    successor = if betweeno(id,identifier,suc) do
      suc
    else
      ndash=closest_prec_node(id,{finger,identifier,pre})
      suc = if ndash==identifier do
        suc
      else
        GenServer.call(globalcall(ndash),:get_suc)
      end
      suc
    end
    { :reply, successor,{finger,identifier,pre} }
  end

  def handle_call({:find_key,id,hop,k},_from,{finger,identifier,pre}) do
    #IO.puts("test1")
    #IO.inspect(List.first(finger))
    {_start,suc} = List.first(finger)
    {successor,h} = if betweeno(id,identifier,suc) do
      {suc,hop+1}
    else
      ndash=closest_prec_node(id,{finger,identifier,pre})
      {suc,hop} = if ndash==identifier do
        {suc,hop+1}
        else
          {GenServer.call(globalcall(ndash),:get_suc),hop+1}
        end
      {suc,hop+1}
    end
      GenServer.cast(NetworkSimulator,{:save_hops,{id,h}})
      { :reply, {successor,h},{finger,identifier,pre} }

  end

  def handle_call({:set_pre,peer},_from,{finger,identifier,_pre}) do
    #IO.inspect("set pre")
    #newpre = if (pre==nil or between(peer,pre,identifier)) do
    #  peer
     # else
    #  pre
    #  end
    #IO.inspect({identifier,peer})
    { :reply,nil,{finger,identifier,peer} }
  end

  def handle_call({:set_prec,peer},_from,{finger,identifier,pre}) do
    #IO.inspect("set pre")
    newpre = if (pre==nil or between(peer,pre,identifier)) do
      peer
     else
      pre
      end
    #IO.inspect({identifier,newpre})
    { :reply,nil,{finger,identifier,newpre} }
  end


  #def handle_cast({:find_key,message},{finger,identifier,pre}) do
   # Process.send_after({})
   # { :noreply,{finger,identifier,pre} }
  #end



  def between(id,l,r) do
    (betweeno(id,l,r) && (id != r))
  end

  def betweeno(id,l,r) do
    mod(r-id,trunc(:math.pow(2,160)))<mod(r-l,trunc(:math.pow(2,160)))
  end



  def closest_prec_node(id,{finger,n,_pre}) do
    result = Enum.reverse(finger) |> Enum.find(fn {_start,peer} ->
        between(peer,n,id)
    end)
    d = case result do
      nil -> n
      _ -> {_s,p} = result
            p
    end
    if(d==nil) do
      n
      else
      d
      end
  end


  def globalcall(a) do
    {:global,a}
  end

  def stabilize() do
    Process.send_after(self(), :stabilize, 500)
  end

  def fix_fingers(n) do
    Process.send_after(self(), {:fix_fingers,n}, 500)
  end

  def check_finger() do
    Process.send_after(self(),:check_finger,10000)
  end



  @spec mod(integer, integer) :: non_neg_integer
  def mod(number, modulus) when is_integer(number) and is_integer(modulus) do
    case rem(number, modulus) do
      remainder when remainder > 0 and modulus < 0 or remainder < 0 and modulus > 0 ->
        remainder + modulus
      remainder ->
        remainder
    end
  end
end
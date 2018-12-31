defmodule ChordProtocol.Peer do
  use GenServer, restart: :temporary
  require Logger

  @timeo 20000
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

  def init({identifier,_dnode}) do
    #initialise finger start values (n+2^i)mod(2^160)
    finger = 0..159 |> Enum.map(fn x ->
      start = rem(trunc(identifier+ trunc(:math.pow(2,x))),trunc(:math.pow(2,160)))
      #IO.inspect(start)
      {start,nil}
    end)
    #IO.inspect(finger)


    #Process.send_after(self(), {:join,dnode}, 10)
    {:ok, {finger, identifier, nil,[]}}
  end

  def handle_info({:join,dnode},{finger, identifier, _pre,slist}) do
    #IO.puts("INIT ")
    #IO.inspect(identifier)
    {p,newfinger} = if (dnode) do
      [{fstart,_} | rest] = finger
      # IO.puts("arb_node")
      #IO.inspect(dnode)
      peer = GenServer.call(globalcall(dnode),{:find_suc,fstart},@timeo)
      pre =  GenServer.call(globalcall(peer),:get_pre,@timeo)
      GenServer.call(globalcall(peer),{:set_pre,identifier})
      nf=[{fstart,peer}|rest] |> Enum.scan(fn (a,b) ->
        {cstart,_cpeer} = a
        {_pstart,ppeer} = b
        cpeer = if (between(cstart,identifier,ppeer)) do
            ppeer
          else
            GenServer.call(globalcall(dnode),{:find_suc,cstart},@timeo)
        end
        {cstart,cpeer}
      end)
      1..159 |>  Enum.each(fn x ->
        p=find_predecessor(mod(trunc(identifier-trunc(:math.pow(2,x))),trunc(:math.pow(2,160))),{finger,identifier,pre})
        if identifier != p do
          GenServer.cast(globalcall(p),{:update_finger,identifier,x})
        end
      end)
      {pre,nf}
    else
      rest = finger |> Enum.map(fn {start,_} ->
        {start,identifier}
      end)
      pre = identifier
      {pre,rest}
    end
    #IO.puts("node,pre")
    #IO.inspect({identifier,p})
    #IO.puts("INIT ")
    #IO.inspect(identifier)
    stabilize(60000*Enum.random(1..5))
    fix_fingers(159,60000)
    #check_finger(60000*2)
    { :noreply, {newfinger, identifier, p,slist} }
  end


  def handle_info(:stabilize,{finger, identifier, pre,slist}) do
    [{start,peer}|rest] = finger
    x = if peer==identifier do
      pre
    else
      try do
        GenServer.call(globalcall(peer),:get_pre,@timeo)
      catch
        :exit, _ -> GenServer.call(globalcall(Enum.at(slist,1)),:get_pre,@timeo)
      end
    end
    peer = if (peer==identifier || between(x,identifier,peer)) && peer != x do
      #IO.puts("set_suc")
      #IO.inspect({identifier,peer,x})
      x
      else
      peer
    end
    if peer != identifier do
    GenServer.cast(globalcall(peer),{:set_prec,identifier})
    #IO.puts("in s")
    #IO.inspect({peer,identifier})
    end
    stabilize(2000*Enum.random(1..5))
    { :noreply, {[{start,peer}|rest], identifier, pre,slist} }
  end

  def handle_info({:fix_fingers,n},{finger, identifier, pre,slist}) do
    {s,_pr} = Enum.at(finger,n)
    {_start,suc} = List.first(finger)
    peer = if betweeno(s,identifier,suc) do
      suc
    else
      ndash=closest_prec_node(s,{finger,identifier,pre})
      suc = if ndash==identifier do
        suc
      else
        try do
          GenServer.call(globalcall(ndash),{:find_suc,s},@timeo)
        catch
          :exit, _ -> GenServer.call(globalcall(Enum.at(slist,1)),{:find_suc,s},@timeo)
        end
      end
      suc
    end
    newfinger = List.replace_at(finger,n,{s,peer})
    n=n-1
    n = if n<0 do
      159
      else
      n
    end
    fix_fingers(n,1000)
    { :noreply, {newfinger, identifier, pre,slist} }
  end

  def handle_info(:check_finger,{finger, identifier, pre,slist}) do
    {_start,peer} = List.first(finger)
    IO.puts("Finger TABLE")
    IO.inspect({identifier,pre,peer})
    IO.inspect(Enum.take(finger,-5))
    #IO.inspect(finger)
    check_finger(60000)
    { :noreply, {finger, identifier, pre,slist} }
  end

  def handle_info(:timeout,{finger,identifier,pre,slist}) do
    IO.puts("Timeout")
    IO.inspect(identifier)
    { :noreply, {finger, identifier, pre,slist} }
  end

  def handle_call(:get_pre,_from,{finger,identifier,pre,slist}) do
    #check_finger()
    { :reply, pre,{finger,identifier,pre,slist} }
  end

  def handle_call(:get_suc,_from,{finger,identifier,pre,slist}) do
    {_start,peer} = List.first(finger)
    { :reply,peer,{finger,identifier,pre,slist} }
  end


  def handle_call({:find_suc,id},_from,{finger,identifier,pre,slist}) do
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
        try do
          GenServer.call(globalcall(ndash),{:find_suc,id},@timeo)
        catch
          :exit, _ -> GenServer.call(globalcall(Enum.at(slist,1)),{:find_suc,id},@timeo)
        end
      end
      suc
    end
    { :reply, successor,{finger,identifier,pre,slist} }
  end

  def handle_call({:find_pre,id},_from,{finger,identifier,pre,slist}) do
    #IO.puts("test1")
    #IO.inspect(List.first(finger))
    p=find_predecessor(id,{finger,identifier,pre})
    { :reply, p,{finger,identifier,pre,slist} }
  end

  def handle_call({:find_key,id,hop,c},_from,{finger,identifier,pre,slist}) do
    #IO.puts("test1")
    #IO.inspect(List.first(finger))
    {_start,suc} = List.first(finger)
    {successor,h} = if betweeno(id,identifier,suc) do
      {suc,hop}
    else
      ndash=closest_prec_node(id,{finger,identifier,pre})
      {suc,hop} = if ndash==identifier do
        {suc,hop}
        else
          try do
            GenServer.call(globalcall(ndash),{:find_key,id,hop+1,c},@timeo)
          catch
            :exit, _ ->  GenServer.call(globalcall(Enum.at(slist,1)),{:find_key,id,hop+1,c},@timeo)
          end
        end
      {suc,hop}
    end
      if(c==identifier) do
      GenServer.cast(NetworkSimulator,{:save_hops,{id,c,identifier,h}})
      end
      { :reply, {successor,h},{finger,identifier,pre,slist} }

  end

  def handle_call({:set_pre,peer},_from,{finger,identifier,_pre,slist}) do
    #IO.inspect("set pre")
    #newpre = if (pre==nil or between(peer,pre,identifier)) do
    #  peer
     # else
    #  pre
    #  end
    #IO.inspect({identifier,peer})
    { :reply,nil,{finger,identifier,peer,slist} }
  end

  def handle_call({:set_succ,peer},_from,{finger,identifier,pre,slist}) do
    {start,suc} = List.first(finger)
    successor = if betweeno(peer,identifier,suc) do
      peer
    else
      suc
    end
    newfinger = List.replace_at(finger,0,{start,successor})
    { :reply, nil,{newfinger,identifier,pre,slist} }
  end

  def handle_cast(:die,state) do
    {:stop, :normal, nil}
  end

  def handle_cast({:set_prec,peer},{finger,identifier,pre,slist}) do
    #IO.inspect("set pre")
    #if(peer != pre) do
     # IO.puts("set_pre")
    #  IO.inspect({identifier,peer})
   # end
    newpre = cond do
      pre == nil -> peer
      between(peer,pre,identifier) -> #GenServer.call(globalcall(pre),{:set_succ,peer})
                                      peer
      true -> pre
    end

    #newpre = if (pre==nil || between(peer,pre,identifier)) do
    #  peer
      #optimization mentioned in section 5
    # else
    #  pre
    #  end
    #IO.inspect({identifier,newpre})
    { :noreply,{finger,identifier,newpre,slist} }
  end

  def handle_cast({:update_finger,s,i},{finger,identifier,pre,slist}) do
    {start,peer} = Enum.at(finger,i)
    npeer = if (between(s,identifier,peer)) do
      if identifier != pre do
        GenServer.cast(globalcall(pre),{:update_finger,s,i})
      end
      s
    else
    peer
    end
    newfinger = if npeer != peer do
      List.replace_at(finger,i,{start,npeer})
      else
      finger
    end
    { :noreply,{newfinger,identifier,pre,slist} }
  end

  def handle_cast({:join_network,dnode},{finger,identifier,pre,slist}) do
    Process.send_after(self(), {:join,dnode}, 10)
    { :noreply,{finger,identifier,pre,slist} }
  end

  def handle_cast({:join_net,p,s,nodes,i},{finger,identifier,_pre,slist}) do

      [{fstart,_} | rest] = finger

      peer = s
      npre =  p
      size = round(:math.log2(length(nodes)))
      slist = Enum.slice(nodes,i+1,size)
      n=size-length(slist)
      slist = slist ++ Enum.slice(nodes,0,n)

      nf=[{fstart,peer}|rest] |> Enum.scan(fn (a,b) ->
        {cstart,_cpeer} = a
        {_pstart,ppeer} = b
        cpeer = if (between(cstart,identifier,ppeer)) do
          ppeer
        else
          #GenServer.call(globalcall(dnode),{:find_suc,cstart},@timeo)
          find_close_node(cstart,nodes)
        end
        {cstart,cpeer}
      end)
      #1..159 |>  Enum.each(fn x ->
      #  p=find_predecessor(mod(trunc(identifier-trunc(:math.pow(2,x))),trunc(:math.pow(2,160))),{finger,identifier,pre})
      #  if identifier != p do
      #    GenServer.cast(globalcall(p),{:update_finger,identifier,x})
      #  end
      #end)

      #IO.inspect( IO.inspect(Enum.take(nf,-3)))

    stabilize(60000*Enum.random(1..5))
    fix_fingers(159,60000)
    GenServer.cast(FailureSimulator,:done)
    { :noreply,{nf,identifier,npre,slist} }
  end

  def handle_cast({:find_msg,id,hop,c},{finger,identifier,pre,slist}) do
    {_start,suc} = List.first(finger)
    {successor,h} = if betweeno(id,identifier,suc) do
      {suc,hop}
    else
      ndash=closest_prec_node(id,{finger,identifier,pre})
      {suc,hop} = if ndash==identifier do
        {suc,hop}
      else
        try do
          GenServer.call(globalcall(ndash),{:find_key,id,hop+1,c},@timeo)
        catch
          :exit, _ ->  GenServer.call(globalcall(Enum.at(slist,1)),{:find_key,id,hop+1,c},@timeo)
        end


      end
      {suc,hop}
    end
    if(c==identifier) do
      GenServer.cast(NetworkSimulator,{:save_hops,{id,c,identifier,h}})
    end
    { :noreply,{finger,identifier,pre,slist} }
  end



  def between(id,l,r) do
    (betweeno(id,l,r) && (id != r))
  end

  def betweeno(id,l,r) do
    l !=nil && r != nil && mod(r-id,trunc(:math.pow(2,160)))<mod(r-l,trunc(:math.pow(2,160)))
  end

  def find_predecessor(id,{finger,identifier,pre}) do
    {_start,suc} = List.first(finger)
    p = if betweeno(id,identifier,suc) do
      identifier
    else
      ndash=closest_prec_node(id,{finger,identifier,pre})
      p = if ndash==identifier do
        identifier
      else
        GenServer.call(globalcall(ndash),{:find_pre,id},@timeo)
      end
      p
    end
    p
  end

  def closest_prec_node(id,{finger,n,_pre}) do
    result = Enum.reverse(finger) |> Enum.find(fn {_start,peer} ->
        peer != nil && between(peer,n,id)
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


  def find_close_node(id,nodes) do
    [_m,n]=Enum.chunk_every(nodes, 2, 1, :discard) |> Enum.find([nil,List.first(nodes)],fn [a,b] ->
    between(id,a,b)
    end)
    n
  end


  def globalcall(a) do
    {:global,a}
  end

  def stabilize(x) do
    Process.send_after(self(), :stabilize, x)
  end

  def fix_fingers(n,x) do
    Process.send_after(self(), {:fix_fingers,n}, x)
  end

  def check_finger(x) do
    Process.send_after(self(),:check_finger,x)
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
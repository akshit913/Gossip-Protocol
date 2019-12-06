defmodule Gossip.Node do
  use GenServer

  ##################### client side ########################

  # initial values are 0:rumor, 1:times heard the rumor, 2:s, 3:w, 4:neighbors tuple,
  # 5:node's mazai process id, mazai is a process spawned from this node and used for keep sending rumors
  # 6:the number of this node(Genserver)
  def start_link(nodename,nodenum) do
      GenServer.start_link(__MODULE__,["",0,nodenum,1,{},nodenum], name: nodename)
  end

  # update neighbor list of a node
  def update_neighbor(nodename,neighbortuple) do
      GenServer.cast(nodename, {:update_neighbor,neighbortuple})
  end

  def get_neighbors(nodename) do
      GenServer.call(nodename, :get_neighbors)
  end

  def get_metadata(nodename) do
      GenServer.call(nodename, :get_metadata)
  end
  # send rumor to this nodename node
  def send_rumor(nodename, rumor, mainpid) do
#      IO.inspect "inside send rumor"
      GenServer.cast(nodename, {:send_rumor,rumor,mainpid})
  end

  def do_pushsum(nodename, s, w, mainpid) do
      GenServer.cast(nodename, {:do_pushsum, s, w, mainpid})
  end
  ################### server side ##########################
  def init(metadata) do
      {:ok, metadata}
  end

  def handle_call(:get_metadata, _from, metadata) do
      {:reply,metadata,metadata}
  end

  def handle_call(:get_neighbors, _from, metadata) do
      neighbors = Enum.at(metadata,4)
      {:reply,neighbors,metadata}
  end

  def handle_cast({:update_neighbor,neighbortuple}, metadata) do
      {:noreply, List.replace_at(metadata,4,neighbortuple)}
  end

  def handle_cast({:send_rumor,rumor,mainpid}, metadata) do
      # if first time heard the rumor, start a side process to keep sending the rumor to its neighbors
#      IO.inspect metadata
      terminatedtime = 100
      sideprocessname = "node"<>Integer.to_string(Enum.at(metadata,6))<>"_child" |> String.to_atom()
      if Process.whereis(sideprocessname) == nil && Enum.at(metadata,1) < terminatedtime  do
#        IO.inspect terminatedtime
        # IO.puts "node child spawned: #{Enum.at(metadata,6)}"
        send mainpid, {:know_rumor}
#        IO.inspect metadata
        neighborlist = Enum.at(metadata,4) |> Tuple.to_list()
#        IO.inspect neighborlist
        sideprocess = spawn(Gossip.Node, :keep_sending_rumor, [rumor, neighborlist, mainpid])
        Process.register(sideprocess, sideprocessname)
      end
      # update its rumor and time to hear field
      newtimetohear = Enum.at(metadata,1) + 1
      newmeta = List.replace_at(metadata,0,rumor)
      newmeta = List.replace_at(newmeta,1,newtimetohear)
      # if this node heard the rumor ten times, stop the side process and tell whole main process that this node has terminated
      if Process.whereis(sideprocessname)!=nil && newtimetohear >= terminatedtime  do
        Process.sleep(5)  # in case two process want to delete sideprocess, the second will delete nil if not adding this clause
        if Process.whereis(sideprocessname)!=nil && newtimetohear >= terminatedtime  do
          sideprocessname |> Process.whereis() |> Process.exit(:kill)
        #   IO.puts "node child terminated: #{Enum.at(metadata,6)}"
        end
      end
      {:noreply, newmeta}
  end

  def handle_cast({:do_pushsum,s,w,mainpid}, metadata) do
      # update s and w of this node
      new_s = (Enum.at(metadata,2) + s) / 2
      new_w = (Enum.at(metadata,3) + w) / 2
      newmeta = List.replace_at(metadata,2,new_s)
      newmeta = List.replace_at(newmeta,3,new_w)
      send mainpid,{:sum_estimate,new_s/new_w}
      # send half of its value out (new_s, new_w are already the halfed value)
      push_to = Enum.at(metadata,4) |> Tuple.to_list() |> choose_a_neighbor()
      do_pushsum(push_to,new_s,new_w,mainpid)
      {:noreply,newmeta}
  end


  def keep_sending_rumor(rumor,neighborlist, mainpid) do
      idx = neighborlist |> length() |> :rand.uniform()
      rumor_to = Enum.at(neighborlist,idx-1) # name of node who will receive the rumor
      send_rumor(rumor_to,rumor,mainpid)
      keep_sending_rumor(rumor,neighborlist,mainpid)
  end

  def choose_a_neighbor(neighborlist) do
      idx = neighborlist |> length() |> :rand.uniform()
      Enum.at(neighborlist,idx-1)
  end

end

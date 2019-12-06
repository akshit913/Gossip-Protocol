defmodule Gossip.Startalg do

    def start_protocol(numnodes, :gossip) do
        IO.puts "start gossip"
        {time,_} = :timer.tc(fn-> start_gossip(numnodes) end)
        IO.puts "gossip finished, every node gets the rumor, time taken for gossip: #{time}us"
    end

    def start_protocol(numnodes, :pushsum) do
        IO.puts "start push sum"
        {time,_} = :timer.tc(fn-> start_pushsum(numnodes) end)
        IO.puts "Time taken for pushsum: #{time}us"
    end

    ####################### gossip algorithm #################################
    def start_gossip(numnodes) do
        firstnode = :rand.uniform(numnodes) |> num_name()
        IO.inspect firstnode
        Gossip.Node.send_rumor(firstnode,"Big Bad Wolf!",self())
        wait_till_all_nodes_know(0,numnodes)
    end

    # convert node number to atom, say 2 -> :node2
    def num_name(nodenum), do: "node"<>Integer.to_string(nodenum) |> String.to_atom()

    def wait_till_all_nodes_know(n,numnodes) when n===numnodes, do: nil # n represents number of nodes knowing the rumor
    def wait_till_all_nodes_know(n,numnodes) when n>=0 do
        receive do
            {:know_rumor} ->  wait_till_all_nodes_know(n+1,numnodes)
        end
    end

    ########################## push sum algorithm ############################
    def start_pushsum(numnodes) do
        firstnode = :rand.uniform(numnodes) |> num_name()
         IO.puts "firstnode #{inspect firstnode}"
        Gossip.Node.do_pushsum(firstnode,0,0,self())
        wait_till_converge(0,1)
    end

    def wait_till_converge(first,second) do
        receive do
          {:sum_estimate,cur} ->
              if converge?(first,second,cur) do
                  IO.puts "Converged! Sum estimate is #{cur}"
              else
                  wait_till_converge(second,cur)
              end
        end
    end

    def converge?(first, second, third) do
        abs(first-second) <= :math.pow(10,-10) && abs(second-third) <= :math.pow(10,-10)
    end
end
#Gossip.CreateNet.build_topology(1000,:line)
#Gossip.Startalg.start_protocol(1000, :gossip)
#Actual Genserver Callback
#def handle_cast(:print_state, state) do
#  IO.inspect state
#  {:noreply, state}
#end
#
#def handle_cast({:update_neighbor, neighborTuple}, state) do
#  state = Map.put(state, :tuple, neighborTuple)
#  {:noreply, state}
#end
#def handle_call(:if_alive, _from,state) do
#  IO.inspect Map.get(state, :alive)
#  {:reply, Map.get(state, :alive), state}
#end
#
#def handle_cast(:get_gossip, state) do
#  value = Map.get(state, :counter)
#  value = value + 1
#  state = Map.put(state, :counter, value)
#  IO.inspect "Rishabh"
#  random_number = :rand.uniform(9)
#  IO.inspect random_number
#  IO.inspect Map.get(state, :tuple)
#  IO.inspect elem(Map.get(state, :tuple), random_number)
#  {:noreply, state}
#end
#def handle_call(:get_gossip, _from ,state) do
#  value = Map.get(state, :counter)
#  value = value + 1
#  state = if (value > 10) do
#    Map.put(state, :alive, false )
#  else
#    Map.put(state, :counter, value)
#  end
#  next_neighbor = get_new_neighbor(state)
#  {:reply, {next_neighbor, state}, state}
#end
#
#def get_new_neighbor(state) do
#  random_number = :rand.uniform(8)
#  next_node = elem(Map.get(state, :tuple), random_number)
#  value = check_if_alive(next_node)
#      IO.puts "Value returned from checking neighbor"
#      IO.inspect value
#  if(value) do
#    next_node
#  else
#    get_new_neighbor(state)
#  end
#end
#end

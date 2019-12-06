defmodule Gossip.CreateNet do
  def build_topology(numNodes, :line) do
    IO.puts "inside build"
    build_n_nodes(numNodes)
    update_neighbor_for_all_nodes_line(numNodes, numNodes)
  end
  def build_n_nodes(1) do
    Gossip.Node.start_link(:node1,1)
  end
  def build_n_nodes(n) when n>1 do
    Gossip.Node.start_link(String.to_atom("node"<>Integer.to_string(n)),n)
    #"node"<>Integer.to_string(n) |> String.to_atom() |> Gossip.Node.start_link(n)
    build_n_nodes(n-1)
  end
  ########### line topology #########################################
  def update_neighbor_for_all_nodes_line(_cur, n) when n==1 do  # cur: current node number, n: total node number
      nil
  end
  def update_neighbor_for_all_nodes_line(cur, n) when cur==n do
      curnode = "node"<>Integer.to_string(cur) |> String.to_atom()
      prevnode = "node"<>Integer.to_string(cur-1) |> String.to_atom()
      Gossip.Node.update_neighbor(curnode, {prevnode})
      update_neighbor_for_all_nodes_line(cur-1, n)
  end
  def update_neighbor_for_all_nodes_line(cur, _n) when cur==1 do
      Gossip.Node.update_neighbor(:node1, {:node2})
  end
  def update_neighbor_for_all_nodes_line(cur, n) when n>1 do
      curnode = "node"<>Integer.to_string(cur) |> String.to_atom()
      prevnode = "node"<>Integer.to_string(cur-1) |> String.to_atom()
      nxtnode = "node"<>Integer.to_string(cur+1) |> String.to_atom()
      Gossip.Node.update_neighbor(curnode, {prevnode,nxtnode})
      update_neighbor_for_all_nodes_line(cur-1, n)
  end
end

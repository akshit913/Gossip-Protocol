defmodule Gossip do
  def main(args) do
    # numnodes topology(full,2D,line,imp2D) algorithm(gossip,push-sum)
    # if topology is 2D or imp2D, numnodes would be round to highest number less than numnodes that can build a grid
    {numnodes,topology,algorithm} = Gossip.Parseargs.parse_args(args)

    IO.puts "start building topology"
    Gossip.CreateNet.build_topology(numnodes, topology)

    IO.puts "start algorithm:"
    Gossip.Startalg.start_protocol(numnodes, algorithm)

  end
end


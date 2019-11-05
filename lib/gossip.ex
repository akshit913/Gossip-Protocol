defmodule Gossip do
  use GenServer

  def main(args) do

    [numNodes, topology, algorithm] = [Enum.at(args,0),Enum.at(args,1),Enum.at(args,2)];

    {numNodes,_} = Integer.parse(numNodes);

     table = :ets.new(:table, [:named_table,:public])
         :ets.insert(table, {"globalCount",0})

      if topology == "rand2D" do

        numNodes = round :math.pow(:math.ceil(:math.sqrt(numNodes)) ,2)

        nodesPID = Enum.map((1..numNodes), fn(x) ->
        pid = start()
        updatePIDState(pid,x)

        pid
        end)
        chooseTopology(topology, nodesPID)
        startTime = System.monotonic_time(:millisecond)

        chooseAlgo(algorithm, nodesPID, startTime)


      else if topology == "3Dtorus" do
        numNodes = round :math.pow(:math.ceil(:math.pow(numNodes, 1/3)),3)
        nodesPID = Enum.map((1..numNodes), fn(x) ->
        pid = start()
        updatePIDState(pid,x)

        pid
        end)
        chooseTopology(topology, nodesPID)
        startTime = System.monotonic_time(:millisecond)


        chooseAlgo(algorithm, nodesPID, startTime)

      else
        nodesPID = Enum.map((1..numNodes), fn(x) ->
          pid = start()
          updatePIDState(pid,x)

          pid
          end)
          chooseTopology(topology, nodesPID)
        startTime = System.monotonic_time(:millisecond)

        chooseAlgo(algorithm, nodesPID, startTime)
      end
      end


    end

    def start() do
      {:ok,pid} = GenServer.start_link(__MODULE__, :ok, [])
      pid
    end

    def init(:ok) do
      {:ok, {0,0,[],0}}
    end

    def updatePIDState(pid, nodeID) do
    # this function and first element of state
      GenServer.call(pid, {:UpdatePIDState, nodeID})
    end

    def handle_call({:UpdatePIDState, nodeID}, _from, state) do
      {a,b,c,d} = state
      state = {nodeID, b, c, d}
      {:reply, a, state}
    end

    def chooseTopology(topology, nodesPID) do
      case topology do
        "full" -> buildFull(nodesPID)
        "line" -> buildLine(nodesPID)
        "rand2D" -> buildRand2D(nodesPID)
        "3Dtorus" -> build3D(nodesPID)
        "honeycomb" -> buildHoneyComb(nodesPID)
        "randhoneycomb" -> buildRandHoneyComb(nodesPID)
      end
    end

    def chooseAlgo(algorithm, nodesPID, startTime) do
      case algorithm do
        "gossip" -> startGossip(nodesPID, startTime)
        "push-sum" -> startPushSum(nodesPID, startTime)
      end
    end

    def buildFull(nodesPID) do
      Enum.each(nodesPID, fn(i) ->
        Enum.each(nodesPID, fn(k) ->
          if(i != k) do
            GenServer.call(i,{:UpdateAdjacentList, k})
          end
        end)
      end)
    end

    def buildHoneyComb(nodesPID) do
      noNodes = Enum.count nodesPID
      n = ceil(noNodes/6)



      Enum.each((0..n-1), fn(row) ->

        if(rem(row,2) == 0) do
          Enum.each((0..5), fn(k) ->
            if(rem(row*6+k,2) == 0 and row*6+k+1 < noNodes) do
              node1 = Enum.fetch!(nodesPID, row*6+k)
              node2 = Enum.fetch!(nodesPID, row*6+k+1)

              GenServer.call(node1,{:UpdateAdjacentList, node2})
              GenServer.call(node2,{:UpdateAdjacentList, node1})
            end
          end)

        else if(rem(row,2) != 0) do
          Enum.each((0..5), fn(k) ->
             if(k==1 || k==3) do

              if(row*6+k+1 < noNodes) do
                n1 = Enum.fetch!(nodesPID, row*6+k)
                n2 = Enum.fetch!(nodesPID, row*6+k+1)
                GenServer.call(n1,{:UpdateAdjacentList, n2})
                GenServer.call(n2,{:UpdateAdjacentList, n1})

              end
            end
            if(row != 0 and row*6+k < noNodes and row*6+k - 6 >=0) do
              n3 = Enum.fetch!(nodesPID, row*6+k - 6)
              n5 = Enum.fetch!(nodesPID, row*6+k)
              GenServer.call(n3,{:UpdateAdjacentList, n5})
              GenServer.call(n5,{:UpdateAdjacentList, n3})

            end
            if(row != n-1 and row*6+k+6 < noNodes ) do
              n4 = Enum.fetch!(nodesPID, row*6+k + 6)
              n5 = Enum.fetch!(nodesPID, row*6+k)
              GenServer.call(n4,{:UpdateAdjacentList, n5})
              GenServer.call(n5,{:UpdateAdjacentList, n4})

            end
          end)
        end
        end
      end)

   end

   def buildRandHoneyComb(nodesPID) do

     buildHoneyComb(nodesPID)
     Enum.each(nodesPID, fn(i) ->
       randNode = Enum.random(nodesPID)
       GenServer.call(i,{:UpdateAdjacentList, randNode})

      end)
    end






    def buildLine(nodesPID) do
      noNodes = Enum.count nodesPID
      Enum.each(nodesPID, fn(i) ->
        ind = Enum.find_index(nodesPID, fn(j) -> i==j end)

        if(ind == 0 ) do

          neighbor = Enum.fetch!(nodesPID, 1)
          GenServer.call(i,{:UpdateAdjacentList,neighbor})
        else if(ind == noNodes-1) do


          neighbor = Enum.fetch!(nodesPID, noNodes - 2)
          GenServer.call(i,{:UpdateAdjacentList,neighbor})
        else

          firstNeighbor = Enum.fetch!(nodesPID, ind-1)
          secondNeighbor = Enum.fetch!(nodesPID, ind+1)
          GenServer.call(i,{:UpdateAdjacentList,firstNeighbor})
          GenServer.call(i,{:UpdateAdjacentList,secondNeighbor})
        end
        end
        #:timer.sleep 100


      end)
    end

    def buildRand2D(allNodes) do
      numNodes=Enum.count allNodes
     numNodesSQR= :math.sqrt numNodes
     Enum.each(allNodes, fn(k) ->
       #count
       currentPosition=Enum.find_index(allNodes, fn(x) -> x==k end)

       #Find the bottom neighbour node a long as it exists (i.e. current position is not in last row)
       if(!isBottom(currentPosition,numNodesSQR)) do
         index=currentPosition + round(numNodesSQR)
         neighbour1=Enum.fetch!(allNodes, index)
         GenServer.call(k, {:UpdateAdjacentList,neighbour1})
       end

        #Find the top neighbour node a long as it exists (i.e. current position is not in first row)
       if(!isTop(currentPosition,numNodesSQR)) do
         index=currentPosition - round(numNodesSQR)
         neighbour2=Enum.fetch!(allNodes, index)
         GenServer.call(k, {:UpdateAdjacentList,neighbour2})
       end
        #Find the left neighbour node a long as it exists (i.e. current position is not in first column)
       if(!isLeft(currentPosition,numNodesSQR)) do
         index=currentPosition - 1
         neighbour3=Enum.fetch!(allNodes,index )
         GenServer.call(k, {:UpdateAdjacentList,neighbour3})
       end

        #Find the right neighbour node a long as it exists (i.e. current position is not in last column)
       if(!isRight(currentPosition,numNodesSQR)) do
         index=currentPosition + 1
         neighbour4=Enum.fetch!(allNodes, index)
         GenServer.call(k, {:UpdateAdjacentList,neighbour4})
       end
     end)
     end




      def addRight(pos, nodesPID,x,k) do
        noNodes=Enum.count nodesPID
        numSqrt= :math.sqrt noNodes
        ind = pos + x
        if ind < noNodes do
          neighbour=Enum.fetch!(nodesPID, ind)
       GenServer.call(k, {:UpdateAdjacentList,neighbour})
     end
     if !(rem(ind+1, round(numSqrt)) == 0) do
          addRight(pos,nodesPID,x+1,k)
        end
      end

      def addDown(pos,nodesPID,x,k) do
     noNodes=Enum.count nodesPID
        numSqrt= :math.sqrt noNodes
        ind = pos + x*round(numSqrt)
        if ind < noNodes do
          neighbour=Enum.fetch!(nodesPID, ind)
       GenServer.call(k, {:UpdateAdjacentList,neighbour})
     end
     if !(ind >= (noNodes-round(numSqrt))) do
          addDown(pos,nodesPID,x+1,k)
        end
      end

      def addLeft(pos, nodesPID,x,k) do
        noNodes=Enum.count nodesPID
        numSqrt= :math.sqrt noNodes
        ind = pos - x
        if ind > -1 do
          neighbour=Enum.fetch!(nodesPID, ind)
       GenServer.call(k, {:UpdateAdjacentList,neighbour})
     end
     if !(rem(ind, round(numSqrt)) == 0) do
          addRight(pos,nodesPID,x+1,k)
        end
      end

      def addUp(pos,nodesPID,x,k) do
     noNodes=Enum.count nodesPID
        numSqrt= :math.sqrt noNodes
        ind = pos - x*round(numSqrt)
        if ind > -1 do
          neighbour=Enum.fetch!(nodesPID, ind)
       GenServer.call(k, {:UpdateAdjacentList,neighbour})
     end
     if !(ind < round(numSqrt)) do
          addDown(pos,nodesPID,x+1,k)
        end
      end


    def isBottom(i,rowLen) do
     length = rowLen*rowLen
     if(i>=(length-rowLen)) do
       true
     else
       false
     end
   end


   def isTop(i,rowLen) do
     if(i< rowLen) do
       true
     else
       false
     end
   end


   def isLeft(i,colLen) do
     if(rem(i,round(colLen)) == 0) do
       true
     else
       false
     end
   end

   def isRight(i,colLen) do
     if(rem(i + 1,round(colLen)) == 0) do

       true
     else
       false
     end
   end



   def build3D(allNodes) do
     numNodes=Enum.count allNodes
     numNodesSQR = :math.sqrt numNodes
     numNodesCubeRoot = :math.pow(numNodes,1/3)

     Enum.each(allNodes, fn(k) ->
       #count
       currentPosition=Enum.find_index(allNodes, fn(x) -> x==k end)


         if(!isBottom(currentPosition,numNodesCubeRoot)) do
           index=currentPosition + round(numNodesCubeRoot)
            neighbour1=Enum.fetch!(allNodes, index)
           GenServer.call(k, {:UpdateAdjacentList,neighbour1})
         end


         if(!isTop(currentPosition,numNodesCubeRoot)) do
             index=currentPosition - round(numNodesCubeRoot)
           neighbour2=Enum.fetch!(allNodes, index)
           GenServer.call(k, {:UpdateAdjacentList,neighbour2})
         end

         if(!isLeft(currentPosition,numNodesCubeRoot)) do
           index=currentPosition - 1
           neighbour3=Enum.fetch!(allNodes,index )
           GenServer.call(k, {:UpdateAdjacentList,neighbour3})
         end


         if(!isRight(currentPosition,numNodesCubeRoot)) do
           index=currentPosition + 1

           neighbour4=Enum.fetch!(allNodes, index)
           GenServer.call(k, {:UpdateAdjacentList,neighbour4})
         end


         if(!isFront(currentPosition,numNodesCubeRoot)) do
             index=currentPosition - round(numNodesCubeRoot*numNodesCubeRoot)
           neighbour5=Enum.fetch!(allNodes, index)
           GenServer.call(k, {:UpdateAdjacentList,neighbour5})
         end


         if(!isBack(currentPosition,numNodesCubeRoot)) do
           index=currentPosition + round(numNodesCubeRoot*numNodesCubeRoot)
           neighbour6=Enum.fetch!(allNodes, index)
           GenServer.call(k, {:UpdateAdjacentList,neighbour6})
         end
     end)
   end


     def isFront(i,numNodesCubeRoot) do
       if(i<round(numNodesCubeRoot*numNodesCubeRoot)) do
           true
       else
           false
       end
     end

     # Check if the current node i lies on the back plane of the matrix
     def isBack(i,numNodesCubeRoot) do
       length = :math.pow(numNodesCubeRoot,3)
       if(i>(length-1-round(numNodesCubeRoot*numNodesCubeRoot))) do
           true
       else
           false
       end
     end

     def startPushSum(nodesPID, startTime) do
       randomFirstNode = Enum.random(nodesPID)
       ind = Enum.find_index(nodesPID, fn(j) -> j==randomFirstNode end)
       currentW =GenServer.call(randomFirstNode, {:UpdateWeight,1})
       currentS =GenServer.call(randomFirstNode, {:UpdateS,ind})
       loopPushSum(randomFirstNode, currentS, currentW,startTime, nodesPID)
     end

   def handle_call({:transmitPS, sentS, sentW, oldW, oldS}, _from, state) do

     {s,b,c,w} = state
     newS = oldS + sentS
     newW = oldW + sentW

     count = 0

     ratioDiff = abs((newS/newW) - (oldS/oldW))
     #IO.puts "#{ratioDiff}"
     state = {newS/2,b,c,newW/2}

     {:reply, ratioDiff, state}

   end





   def loopPushSum(node, s, w, startTime, nodesPID) do


       oldW = GenServer.call(node,{:GetWeight})
       oldS = GenServer.call(node,{:GetS})
        #IO.inspect(node)
     adjList = getAdjacentList(node)
     randomNode = Enum.random(adjList)
     c = GenServer.call(randomNode,{:GetCount})
     rat = GenServer.call(randomNode, {:transmitPS,s/2,w/2,oldW,oldS})

     if(rat<:math.pow(10,-10)) do
           if c<=2 do
             c = c + 1
             GenServer.call(randomNode,{:UpdateCount,c})

            else if c==3 do
               count = :ets.update_counter(:table, "globalCount", {2,1})
               #IO.puts "#{count}"
              #IO.puts "#{length(nodesPID)}"
               if count ==  length(nodesPID) do
                 endTime = System.monotonic_time(:millisecond) - startTime
                 IO.puts "Convergence time for push-sum for #{count} nodes was achieved in " <> Integer.to_string(endTime) <>" Milliseconds"
                 :timer.sleep(100)
                 System.halt(1)
                else
                     c = 4
                     GenServer.call(randomNode,{:UpdateCount,c})
                     adj = Enum.random(adjList)
                     newW = GenServer.call(randomNode,{:GetWeight})
                     newS = GenServer.call(randomNode,{:GetS})
                     loopPushSum(randomNode, newS, newW,startTime,nodesPID)
                 end
             end
             end

        else if (rat>=:math.pow(10,-10)) do
           #IO.puts "aass"
             if c ==2 do
               #IO.puts "aa"
               :ets.update_counter(:table, "globalCount", {2,-1})
             end

             c = 0
             GenServer.call(randomNode,{:UpdateCount,c})

         end
         end

         newW = GenServer.call(randomNode,{:GetWeight})
          newS = GenServer.call(randomNode,{:GetS})


     loopPushSum(randomNode, newS, newW,startTime,nodesPID)

   end


    def handle_call({:UpdateAdjacentList, nodeID}, _from, state) do
      {a,b,c,d} = state
      state = {a,b,c ++ [nodeID],d}

      {:reply,c,state}
    end

    def startGossip(nodesPID, startTime) do
      randFirstNode = Enum.random(nodesPID)
      GenServer.cast(randFirstNode, {:UpdateCount,nodesPID,startTime})
      loopGossip(randFirstNode,startTime, nodesPID)
    end

    def handle_call({:UpdateCount,c}, _from, state) do
      {a,b,e,d} = state
      state = {a,c,e,d}
      {:reply, b, state}
    end

    def handle_call({:GetCount}, _from, state) do
      {_,b,_,_} = state
      {:reply, b, state}
    end

    def loopGossip(randNode, startTime, nodesPID) do
      gossipCount = GenServer.call(randNode, {:GetCount})


      if gossipCount >10 do

          Process.exit(randNode, :normal)
         adjList = getAdjacentList(randNode)
         randomAdjacent=Enum.random(adjList)
         loopGossip(randomAdjacent, startTime, nodesPID)
      else

        adjList = getAdjacentList(randNode)
        gossipTransmission(adjList, startTime, nodesPID)

      end

    end


    def getAdjCount(pid) do
      n = GenServer.call(pid,{:GetAdjacentList})
      a = Enum.count n
      a
    end

    def getAdjacentList(pid) do
      GenServer.call(pid,{:GetAdjacentList})

    end

    def handle_call({:GetAdjacentList}, _from, state) do

      {_,_,c,_} = state



      {:reply,c,state}
    end

    def handle_call({:UpdateWeight, w}, _from, state) do
      {d,e,f,y} = state

      state = {d,e,f,w}

      {:reply, w, state}
    end

    def handle_call({:UpdateS, s}, _from, state) do
      {y,d,e,f} = state
      state = {s,d,e,f}

      {:reply, s, state}
    end

    def handle_call({:GetWeight}, _from, state) do
      {_,_,_,w} = state
      {:reply, w, state}
    end

    def handle_call({:GetS}, _from, state) do
      {s,_,_,_} = state
      {:reply, s, state}
    end


    def handle_cast({:UpdateCount,nodesPID,startTime}, state) do
      {a,c,b,e} = state
     if(c==0) do
         nodeCount = :ets.update_counter(:table, "globalCount", {2,1})
        # IO.puts "#{nodeCount}"
         if(nodeCount >= length(nodesPID)) do
           endTime = System.monotonic_time(:millisecond) - startTime
           IO.puts "Convergence for gossip was achieved in #{endTime} Milliseconds"
           :timer.sleep(1)
           System.halt(1)
         end
     end
      state = {a,c+1,b,e}
      {:noreply, state}
    end


    def gossipTransmission(adjList, startTime, nodesPID) do

      randAdjNode = Enum.random(adjList)
      transmitGossip(randAdjNode, startTime, nodesPID)
    end

    def transmitGossip(randAdjNode, startTime, nodesPID) do
     #IO.inspect (randAdjNode)
      GenServer.cast(randAdjNode,{:UpdateCount,nodesPID,startTime})
      loopGossip(randAdjNode, startTime, nodesPID)
    end
 end












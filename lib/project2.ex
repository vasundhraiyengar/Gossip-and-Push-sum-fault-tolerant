defmodule Project2 do

  use GenServer

  def main(args) do
    numNodes=Enum.at(args, 0)|>String.to_integer()
    topology=Enum.at(args, 1)
    algorithm=Enum.at(args, 2)
    kill_nodes=Enum.at(args, 3)
     
    numNodes=
      if(topology=="torus") do
       get_numNodes(numNodes)  
      else
       numNodes
      end
    IO.inspect(numNodes)
      
    node_collection = Enum.map((1..numNodes), fn(i) ->
      pid=start_link()
      GenServer.call(pid, {:Allot_ID,i})
      pid
    end)


    tablex= :ets.new(:tablex, [:named_table,:public])
    :ets.insert(tablex, {"convergence_count",0})

    case topology do
      "full" -> full(node_collection)
      "line" -> line(node_collection)
      "torus" -> torus(node_collection)
      "3D"-> grid3D(node_collection)
      "rand2D" -> rand2D(node_collection)
      "impline" -> imp2D(node_collection)
    end
     

    num_nodes=
    if (topology=="3D") do
      total_nodes= Enum.count node_collection
      cube_root= :math.pow(total_nodes,1/3)
      z2=trunc(cube_root)
      x2=z2
      y2=z2
        cube=
        if((cube_root-trunc(cube_root))!=0) do
          :math.pow(z2,3)
        else
          :math.pow(cube_root,3)
        end
      cube
    end

    new_node_collection=
    if (topology=="3D") do      
      num_nodes_round=trunc(num_nodes)
      new_node_collection=Enum.map((0..num_nodes_round-1), fn(i) ->
      GenServer.call(Enum.fetch!(node_collection, i), {:Allot_ID,i+1})
      Enum.fetch!(node_collection, i)
      end)
    else
      
    end

    start_time=System.monotonic_time(:millisecond)   

    if (topology=="3D")  do
      Loop_kill.loop_kill(kill_nodes,new_node_collection)
    else    
      Loop_kill.loop_kill(kill_nodes,node_collection)
    end
     
    case algorithm do
     "gossip" -> if (topology=="3D") do
      gossip(new_node_collection,start_time)
      else
        gossip(node_collection,start_time)
      end
    
     "pushsum" -> if (topology=="3D") do
        push_sum(new_node_collection,start_time)
      else
        push_sum(node_collection,start_time)
      end
    end

    infinite()
  end

  def infinite() do
    infinite()
  end

  def get_numNodes(numNodes) do
    round :math.pow(:math.ceil(:math.sqrt(numNodes)) ,2)
  end

    #3DStart
    def grid3D(node_collection) do
      total_nodes= Enum.count node_collection
        cube_root= :math.pow(total_nodes,1/3)
        z2=trunc(cube_root)
        x2= z2
        y2= z2
        if((cube_root-trunc(cube_root))!=0) do
                cube=:math.pow(z2,3)
                offset = total_nodes - cube
                z2 = z2 + (offset / trunc(:math.pow(x2,2)) + 1 )
        end

      i=0
      z3 = trunc( :math.pow(x2,2))
      y3 = x2
      x3 = x2 - 1
      y4 = y2 - 1
      z4 = z2 - 1

      Loop3D_1.loop3D_1(0,0,0,x3,y3,z3,y4,z4,node_collection)
    end  


    # 3D END

        
    def torus(node_collection) do
      total_nodes=Enum.count node_collection
      nodes_sqrt= :math.sqrt total_nodes
    
      Enum.each(node_collection, fn(i) ->
        adjacent_nodes=[]
        neighbour=[]
        node_index=Enum.find_index(node_collection, fn(j) -> j==i end)
        index=0
        adjacent_nodes=
        if(top(node_index,total_nodes)) do
            index = round(total_nodes-((:math.sqrt total_nodes)-index))
            
            neighbour=Enum.at(node_collection, index)
            adjacent_nodes ++ [neighbour]
        else
            index = round(node_index - round(:math.sqrt total_nodes))
            neighbour= Enum.fetch!(node_collection, index)
            adjacent_nodes ++ [neighbour]
        end
          
        adjacent_nodes=
          if(bottom(node_index,total_nodes)) do
            index=round(node_index -(total_nodes-(:math.sqrt total_nodes)))
            neighbour=Enum.fetch!(node_collection, index)
            adjacent_nodes ++ [neighbour]
          else
            index= round(node_index + round(:math.sqrt total_nodes))
            neighbour=Enum.fetch!(node_collection, index)
          adjacent_nodes ++ [neighbour]
          end

        adjacent_nodes =
        if(left(node_index,total_nodes)) do
            index=round(node_index+((:math.sqrt total_nodes)-1))
            neighbour=Enum.fetch!(node_collection, index)
            adjacent_nodes ++ [neighbour] 
        else   
            neighbour=Enum.fetch!(node_collection, node_index-1)
            adjacent_nodes ++ [neighbour]
        end

        adjacent_nodes=
        if(right(node_index,total_nodes)) do
            index=round(node_index-((:math.sqrt total_nodes)-1))
            neighbour=Enum.fetch!(node_collection, index)
            adjacent_nodes ++ [neighbour]
        else
            neighbour=Enum.fetch!(node_collection, node_index + 1)
            adjacent_nodes ++ [neighbour]
        end

        GenServer.cast(i,{:Allot_Adjacent,adjacent_nodes})

      end)
    end


    def top(index,total) do
      if(index< round(:math.sqrt total) ) do
        true
      else
        false
      end
    end

    def left(index,total) do
      if(round(rem(index,round(:math.sqrt(total)))) == 0) do
        true
      else
        false
      end
    end

    def right(index,total) do
      if(round(rem(index + 1,round(:math.sqrt(total)))) == 0) do
        true
      else
        false
      end
    end

    def bottom(index,total) do
      if(index>=(total-round((:math.sqrt total)))) do
        true
      else
        false
      end
    end

    def allot_adjs(process_id, adjacent_nodes) do
      GenServer.cast(process_id, {:Allot_Adjacent,adjacent_nodes})
    end

    def full(node_collection) do
      Enum.each(node_collection, fn(process_id) ->
        adjacent_nodes=List.delete(node_collection,process_id)
        GenServer.cast(process_id, {:Allot_Adjacent,adjacent_nodes})
      end)
    end

    def line(node_collection) do
          total_nodes=Enum.count node_collection
          Enum.each(node_collection, fn(j) ->
            node_index=Enum.find_index(node_collection, fn(i) -> i==j end)
            cond do
              total_nodes==node_index+1 ->
                neighbour_left=Enum.fetch!(node_collection, node_index - 1)
                adjacent_nodes=[neighbour_left]
                GenServer.cast(j, {:Allot_Adjacent,adjacent_nodes})
              node_index==0 ->
                neighbour_right=Enum.fetch!(node_collection, node_index + 1)
                adjacent_nodes=[neighbour_right]
                GenServer.cast(j, {:Allot_Adjacent,adjacent_nodes})
              true ->
                neighbour_right=Enum.fetch!(node_collection, node_index + 1)
                neighbour_left=Enum.fetch!(node_collection, node_index - 1)
                adjacent_nodes=[neighbour_right,neighbour_left]
                GenServer.cast(j, {:Allot_Adjacent,adjacent_nodes})
            end
          end)
    end

    def imp2D(node_collection) do
      total_nodes=Enum.count node_collection
      Enum.each(node_collection, fn(j) ->
      node_index=Enum.find_index(node_collection, fn(i) -> i==j end)
        cond do
          total_nodes==node_index+1 ->
            neighbour_left=Enum.fetch!(node_collection, node_index - 1)
            nc= List.delete(node_collection,neighbour_left)
            nc= List.delete(nc,j)
            neighbour_random=Enum.random(nc)
            adjacent_nodes=[neighbour_left,neighbour_random]
            GenServer.cast(j, {:Allot_Adjacent,adjacent_nodes})
          node_index==0 ->
            neighbour_right=Enum.fetch!(node_collection, node_index + 1)
            nc=List.delete(node_collection,neighbour_right)
            nc=List.delete(nc,j)
            neighbour_random=Enum.random(nc)
            adjacent_nodes=[neighbour_right, neighbour_random]
            GenServer.cast(j, {:Allot_Adjacent,adjacent_nodes})
          true ->
            neighbour_right=Enum.fetch!(node_collection, node_index + 1)
            neighbour_left=Enum.fetch!(node_collection, node_index - 1)
            nc= List.delete(node_collection,neighbour_right)
            nc=List.delete(nc,j)
            nc=List.delete(nc,neighbour_right)
            neighbour_random=Enum.random(nc)
            adjacent_nodes=[neighbour_right,neighbour_left,neighbour_random]
            GenServer.cast(j, {:Allot_Adjacent,adjacent_nodes})
        end
      end)
    end

    def rand2D(node_collection) do
      map=%{}
      n=length(node_collection)-1
      mapc=Loop.loop(node_collection,map,n)
      Loop2.loop2(node_collection, mapc, length(node_collection)-1)
    end

    def handle_cast({:Allot_Adjacent,adjacent_nodes},state) do
      
      {node_id,adjacent_list,w,count}=state
      state={node_id,adjacent_nodes,w,count}
      {:noreply,  state}
    end


    def start_link() do
      {:ok,pid}=GenServer.start_link(__MODULE__,[])
      pid
    end

    def init([]) do
      {:ok, {0,[],1,0}} 
    end

    def handle_call({:Allot_ID,nodeID}, _from, state) do
      {node_id,adjacent_list,w,count}=state
      state={nodeID,adjacent_list,w,count}
      {:reply,nodeID, state}
    end

    #startgossip
    def gossip(node_collection, start_time) do
      starting_node_pid = Enum.random(node_collection)
      check_alive=Process.alive?(starting_node_pid)
      starting_node_pid =
      if (check_alive == false) do
        node=Loop_nextnode.loop_nextnode(node_collection,starting_node_pid, false)
        node
      else
        starting_node_pid
      end

      total_nodes=length(node_collection)
      GenServer.cast(starting_node_pid, {:Update_Count, total_nodes, start_time})
      GenServer.cast(starting_node_pid, {:Pass_Gossip,total_nodes, start_time})

    end

    defmodule Loop_con do
      def loop_con(start_time, convergence_count1, convergence_count2) when convergence_count1==convergence_count2 do
      IO.puts("Nodes covered: #{convergence_count1}")
      end_time=System.monotonic_time(:millisecond)
      conv_time =  end_time- start_time
      IO.puts "Convergence time for covered nodes is = #{conv_time} ms"
      System.halt(1)
      end

      def loop_con(start_time, convergence_count1, convergence_count2) do
        convergence_count1 = elem(List.last(:ets.lookup(:tablex, "convergence_count")),1)
        Process.sleep(5000)
        convergence_count2 = elem(List.last(:ets.lookup(:tablex, "convergence_count")),1)
        Loop_con.loop_con(start_time, convergence_count1, convergence_count2)
      end

    end
  
    def stop_algo(start_time) do
      convergence_count = elem(List.last(:ets.lookup(:tablex, "convergence_count")),1)
      Loop_con.loop_con(start_time, convergence_count, 0)
    end
    
    def handle_cast({:Pass_Gossip,total_nodes, start_time},state) do
        {node_id,adjacent_list,w,count}=state
        adjacent_node=Enum.random(adjacent_list)

        check_alive=Process.alive?(adjacent_node)
        if (check_alive == false) do
          stop_algo(start_time)
        end
    
        GenServer.cast(adjacent_node,{:Gossip_Recursion,total_nodes,start_time})
        if count < 10 do
            Process.send_after(self, {:Give_Time, total_nodes, start_time}, 100)
        end 
        {:noreply,state}
    end

    def handle_cast({:Gossip_Recursion,total_nodes, start_time}, state) do
        {:noreply,state} = handle_cast({:Update_Count, total_nodes, start_time}, state)
        {:noreply,state}=handle_cast({:Pass_Gossip,total_nodes, start_time},state)
        {:noreply,state}
    end

    def handle_info({:Give_Time,total_nodes, start_time}, state) do
      handle_cast({:Pass_Gossip,total_nodes, start_time},state)
    end

    def handle_cast({:Update_Count, total_nodes, start_time}, state) do
      {node_id,adjacent_list,w,count}=state
      if(count==0) do
        convergence_count = :ets.update_counter(:tablex, "convergence_count", {2,1})
    
        if(convergence_count == total_nodes) do
          end_time=System.monotonic_time(:millisecond)
          conv_time =  end_time- start_time
          IO.puts "Convergence Time = #{conv_time} ms"
          System.halt(1)
        end

      end
      state={node_id,adjacent_list,w,count+1}
      {:noreply,state}
    end

    def handle_cast({:Update_Count, total_nodes, start_time}, state) do
      {node_id,adjacent_list,w,count}=state
      if(count==0) do
        convergence_count = :ets.update_counter(:tablex, "convergence_count", {2,1})
        
        if(convergence_count == total_nodes) do
          end_time=System.monotonic_time(:millisecond)
          conv_time =  end_time- start_time
          IO.puts "Convergence Time = #{conv_time} ms"
          System.halt(1)
        end
      end
      state={node_id,adjacent_list,w,count+1}
      {:noreply,state}
    end

    def handle_call({:Get_Adjacents}, _from ,state) do
      {node_id,adjacent_list,w,count}=state
      
      {:reply, adjacent_list, state}
    end

    def handle_call({:Get_Count}, _from ,state) do
      {node_id,adjacent_list,w,count}=state
      {:reply,count, state}
    end

    #gossipend
    def push_sum(node_collection, start_time) do
       starting_node_pid = Enum.random(node_collection)
       check_alive=Process.alive?(starting_node_pid)
       starting_node_pid=
      if (check_alive == false) do
        node=Loop_nextnode.loop_nextnode(node_collection,starting_node_pid, false)
        node
      else
        starting_node_pid
      end
       GenServer.cast(starting_node_pid,{:one,0,0,length(node_collection),start_time})   
    end
  

    def handle_cast({:one,s1,w1,total,start_time},state) do
      
      {s,adjacent_nodes,w,sw_count} = state
    
      newS = s + s1
      newW = w + w1

      diff = abs((newS/newW) - (s/w))
     
      if((diff < :math.pow(10,-10)) && (sw_count==2)) do

        con_count = :ets.update_counter(:tablex, "convergence_count", {2,1})

        if con_count == total-100 do
          
          end_time = System.monotonic_time(:millisecond) - start_time
          IO.puts "Convergence Time = " <> Integer.to_string(end_time) <>" Milliseconds"
         
          System.halt(1)
        end
      end

     count = updateCount(diff,sw_count)
     state = {newS/2,adjacent_nodes,newW/2,count}

      next_node = Enum.random(adjacent_nodes)
      check_alive=Process.alive?(next_node)
      next_node=
      if (check_alive == false) do
        next_node_new=Loop_nextnode.loop_nextnode(adjacent_nodes,next_node, false)
        next_node_new
      else
        next_node
      end
      
      GenServer.cast(next_node, {:one,newS/2,newW/2,total,start_time})
      
      {:noreply,state}
    end

    def updateCount(diff,sw_count) do
      if ((diff < :math.pow(10,-10)) && (sw_count<2)) do
        sw_count+1
      else
        if(diff > :math.pow(10,-10)) do
        0
        end
      end
    end

end

defmodule Loop_nextnode do
  def loop_nextnode(adjacent_list,next_node, check) when check==true do
    next_node
  end
  def loop_nextnode(adjacent_list, next_node, check) do
    next_node=Enum.random(adjacent_list)
    check=Process.alive?(next_node)
    loop_nextnode(adjacent_list,next_node, check)
  end
end

defmodule Loop3D_1 do
  def loop3D_1(x,y,z,x4,y4,z4,y3,z3,node_collection) when z>z4 do
      
  end
  def loop3D_1(x,y,z,x4,y4,z4,y3,z3,node_collection) do
      Loop3D_2.loop3D_2(x,0,z,x4,y4,z4,y3,z3,node_collection)
      loop3D_1(x,y,z+1,x4,y4,z4,y3,z3,node_collection)
  end
end

defmodule Loop3D_2 do
  def loop3D_2(x,y,z,x4,y4,z4,y3,z3,node_collection) when y>y4 do
      
  end
  def loop3D_2(x,y,z,x4,y4,z4,y3,z3,node_collection) do
      Loop3D_3.loop3D_3(0,y,z,x4,y4,z4,y3,z3,node_collection)
      loop3D_2(x,y+1,z,x4,y4,z4,y3,z3,node_collection)
  end
end

defmodule Loop3D_3 do
  def loop3D_3(x,y,z,x4,y4,z4,y3,z3,node_collection) when x>x4 do
   
  end
  def loop3D_3(x,y,z,x4,y4,z4,y3,z3,node_collection) do
      i=z*z3+y*y3+x
          
      numNodes=Enum.count node_collection
      neighbours=[]
      
      if (i < numNodes) do
          pid = Enum.fetch!(node_collection, i)
          
          neighbours = 
          if (x > 0) do
              neighbours ++ [Enum.fetch!(node_collection, i-1)]
          else
            neighbours
          end
           neighbours=
          if (x < x4 && (i + 1) < numNodes) do
              neighbours ++ [Enum.fetch!(node_collection, i+1)]
          else
            neighbours
          end
           neighbours=
          if (y > 0) do
              neighbours ++ [Enum.fetch!(node_collection, i - y3)]
          else
            neighbours
          end
          neighbours=
          if (y < y4 && (i + y3) < numNodes) do
              neighbours ++ [Enum.fetch!(node_collection, i + y3)]
          else
            neighbours
          end
          neighbours=
          if (z > 0) do
              neighbours ++ [Enum.fetch!(node_collection, i - z3)]
          else
            neighbours
          end
          neighbours=
          if (z < z4 && (i + z3) < numNodes) do
              neighbours ++ [Enum.fetch!(node_collection, i + z3)]
          else
            neighbours
          end

          Project2.allot_adjs(pid, neighbours)

      end
          
      Loop3D_3.loop3D_3(x+1,y,z,x4,y4,z4,y3,z3,node_collection)
      
  end
end

defmodule Loop do

  def loop(node_collection, map,n) when n<0 do
    map
  end

  def loop(node_collection, map, n) do
    x=:random.uniform()
    y=:random.uniform()
    process_id=Enum.fetch!(node_collection, n)
    if (n==(length(node_collection)-1)) do
      Loop.loop(node_collection, Map.put(map,process_id, [x,y]), n-1)
    else
      check=map|>Enum.find(fn {key,val} ->val == [x,y] end)
      if (check==nil) do 
        Loop.loop(node_collection, Map.put(map,process_id, [x,y]), n-1)
      else
        Loop.loop(node_collection, map, n)
      end
    end
  end

end

defmodule Loop2 do
  def loop2(node_collection, mapc, i) when i<0 do

  end
  def loop2(node_collection, mapc, i) do
    coords=Map.get(mapc, Enum.fetch!(node_collection, i))
    x=hd(coords)
    y=List.last(coords)
    new_list=List.delete(node_collection, i)
    adj_dummy=[]
    adj_list=Loop3.loop3(x,y, mapc, new_list, adj_dummy, length(new_list)-1)
    Project2.allot_adjs(Enum.fetch!(node_collection, i),adj_list)
    Loop2.loop2(node_collection, mapc, i-1)
  end
end

defmodule Loop3 do
  def loop3(x,y, mapc, new_list, adj_list, j) when j<0 do
    adj_list
  end

  def loop3(x,y, mapc, new_list, adj_list, j) do
    coords=Map.get(mapc, Enum.fetch!(new_list, j))
    x1=hd(coords)
    y1=List.last(coords)
    z=(:math.sqrt(:math.pow(x-x1,2)+:math.pow(y-y1,2)))
    if ((:math.sqrt(:math.pow(x-x1,2)+:math.pow(y-y1,2)))<=0.1) do
      neighbour=Enum.fetch!(new_list, j)
      Loop3.loop3(x,y, mapc, new_list, adj_list ++ [neighbour], j-1)
    else
      Loop3.loop3(x,y, mapc, new_list, adj_list, j-1)
    end
  end
end

defmodule Loop_kill do
  def loop_kill(n, list) when n<1 do

  end
  def loop_kill(n,list) do
    pid=Enum.random(list)
    GenServer.stop(pid)
    loop_kill(n-1, List.delete(list,pid))
  end
   
 end
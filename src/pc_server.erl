
-module(pc_server).
-author("Agnieszka").

-export([start/0, spawn_buffers/2, buffer/1, producer/1, consumer/1, spawn_producer/2, spawn_consumer/2, server/2]).


producer(Server)-> % porcje wielkości 1
  timer:sleep(100),
  Produced = rand:uniform(100),
  Server ! {p, Produced, self()},
  receive
    {toProd} -> io:format("Produced: ~p~n", [Produced])
  end,
  producer(Server).

consumer(Server)->
  timer:sleep(100),
  Server ! {c, self()}, % żądanie porcji do skonsumowania
  receive
    {ToConsume} -> io:format("Consumed: ~p~n", [ToConsume])
  end,
  consumer(Server).

buffer(Element) ->
  case Element of
    -1 ->
      receive
        {p, Produced, Server_PID} ->
          Server_PID ! {toProd},
          io:format("Buffer - received: ~p~n", [Produced]),
          buffer(Produced)
      end;
    _ ->
      receive
        {c, Server_PID} ->
          Server_PID ! {toCons, Element},
          buffer(-1)
      end
  end.


% server handling requests from producers and consumers
server(Free_list, Occupied_list)->
  case {Free_list, Occupied_list} of
    {[], _} ->
      receive
        {c, Consumer_PID} ->
          PID_Occ = lists:nth(1, Occupied_list),
          PID_Occ ! {c, self()},
          receive
            {toCons, Value} -> Consumer_PID ! {Value}
          end,
          New_free_list = Free_list ++ [PID_Occ],
          New_occupied_list = Occupied_list -- [PID_Occ],
          server(New_free_list, New_occupied_list)
      end;
    {_, []} ->
      receive
        {p, Produced, Producer_PID} ->
          PID_Free = lists:nth(1, Free_list),
          PID_Free ! {p, Produced, self()},
          receive
            {toProd} -> Producer_PID ! {toProd}
          end,
          New_free_list = Free_list -- [PID_Free],
          New_occupied_list = Occupied_list ++ [PID_Free],
          server(New_free_list, New_occupied_list)
      end;
    _ ->
      receive
        {p, Produced, Producer_PID} ->
          PID_Free = lists:nth(1, Free_list),
          PID_Free ! {p, Produced, self()},
          receive
            {toProd} -> Producer_PID ! {toProd}
          end,
          New_free_list = Free_list -- [PID_Free],
          New_occupied_list = Occupied_list ++ [PID_Free],
          server(New_free_list, New_occupied_list);
        {c, Consumer_PID} ->
          PID_Occ = lists:nth(1, Occupied_list),
          PID_Occ ! {c, self()},
          receive
            {toCons, Value} -> Consumer_PID ! {Value}
          end,
          New_free_list = Free_list ++ [PID_Occ],
          New_occupied_list = Occupied_list -- [PID_Occ],
          server(New_free_list, New_occupied_list)
      end
  end.


spawn_buffers(N, Buffer_list) ->
  case N of
    0 -> Buffer_list;
    _ ->
      Curr_PID = spawn(pc_server, buffer, [-1]),
      spawn_buffers(N - 1, Buffer_list ++ [Curr_PID])
  end.

spawn_producer(How_many, Server) ->
  timer:sleep(50),
  case How_many of
    0 -> io:format("Producers spawned~n");
    _Else ->
      spawn(pc_server, producer, [Server]),
      spawn_producer(How_many - 1, Server)
  end.

spawn_consumer(How_many, Server) ->
  timer:sleep(50),
  case How_many of
    0 -> io:format("Consumers spawned~n");
    _Else ->
      spawn(pc_server, consumer, [Server]),
      spawn_consumer(How_many - 1, Server)
  end.

start() ->
  N = 10,
  Buffer_list = spawn_buffers(N, []),
  Server = spawn(pc_server, server, [Buffer_list, []]),
  spawn_producer(10, Server),
  spawn_consumer(10, Server).
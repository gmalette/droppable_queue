defmodule DroppableQueue do
  use GenServer

  def start_link(opts \\ []) do
    drop_end = case Keyword.get(opts, :drop_end, :front) do
      drop_end when drop_end in [:front, :back] -> drop_end
      _ -> raise ArgumentError, message: "invalid argument drop_end"
    end
    max = case Keyword.get(opts, :max, 10) do
      max when is_number(max) and (max > 0) -> max
      _ -> raise ArgumentError, message: "invalid argument max"
    end

    GenServer.start_link(__MODULE__, %{max: max, drop_end: drop_end, queue: :queue.new, dropped: 0, waiters: []})
  end

  def push(pid, item, drop_fn \\ nil) do
    GenServer.call(pid, {:push, item, drop_fn})
  end

  def pop(pid) do
    case GenServer.call(pid, {:pop}) do
      {:ok, _, _} = ret -> ret
      :block -> receive do
        {:resume, {:ok, _, 0} = ret} -> ret
      end
    end
  end

  #
  # Callbacks
  #

  def init(state) do
    {:ok, state}
  end

  # The queue is full, need to drop items using fn
  def handle_call({:push, item, func}, from, %{queue: queue={left, right}, max: max, dropped: dropped} = state) when length(left) + length(right) >= max and is_function(func) do
    new_queue = :queue.filter(&(!func.(&1)), queue)
    dropped_now = :queue.len(queue) - :queue.len(new_queue)
    dropped = dropped + dropped_now
    {:reply, {:ok, new_dropped}, state} = handle_call({:push, item, nil}, from, %{state | dropped: dropped, queue: new_queue})
    {:reply, {:ok, dropped_now + new_dropped}, state}
  end

  # The queue is full, need to drop items from the front before adding more
  def handle_call({:push, item, _fun}, _from, %{queue: queue={left, right}, max: max, drop_end: :front, dropped: dropped} = state) when length(left) + length(right) >= max do
    {{:value, _}, new_queue} = :queue.out(queue)
    new_queue = :queue.in(item, new_queue)
    {:reply, {:ok, 1}, %{state | queue: new_queue, dropped: dropped + 1}}
  end

  # the queue is full, need to drop items from the back (just drop them on the floor)
  def handle_call({:push, item, _fun}, _from, %{queue: queue={left, right}, max: max, drop_end: :back, dropped: dropped} = state) when length(left) + length(right) >= max do
    {:reply, {:ok, 1}, %{state | dropped: dropped + 1}}
  end

  def handle_call({:push, item, _fun}, _from, %{queue: {[], []}, waiters: [first|remaining]} = state) do
    send(first, {:resume, {:ok, item, 0}})
    {:reply, {:ok, 0}, %{state | waiters: remaining}}
  end

  def handle_call({:push, item, _fun}, _from, %{queue: queue} = state) do
    new_queue = :queue.in(item, queue)
    {:reply, {:ok, 0}, %{state | queue: new_queue,}}
  end

  def handle_call({:pop}, {waiter, _}, %{queue: queue={left, right}, waiters: waiters} = state) when length(left) + length(right) == 0 do
    {:reply, :block, %{state | waiters: [waiter|waiters]}}
  end

  def handle_call({:pop}, _, %{queue: queue, dropped: dropped} = state) do
    {{:value, item}, new_queue} = :queue.out(queue)
    {:reply, {:ok, item, dropped}, %{state | queue: new_queue, dropped: 0}}
  end
end

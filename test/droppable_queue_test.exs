defmodule DroppableQueueTest do
  use ExUnit.Case, async: true
  doctest DroppableQueue

  test "#start_link returns error if drop_end is unknown" do
    assert_raise(ArgumentError, fn ->
      DroppableQueue.start_link(drop_end: :toto)
    end)
  end

  test "#start_link returns error if max is unknown" do
    assert_raise(ArgumentError, fn ->
      DroppableQueue.start_link(max: :toto)
    end)

    assert_raise(ArgumentError, fn ->
      DroppableQueue.start_link(max: -1)
    end)
  end

  test "it can push and pop messages" do
    {:ok, queue} = DroppableQueue.start_link
    {:ok, _} = DroppableQueue.push(queue, 1)
    {:ok, _} = DroppableQueue.push(queue, 2)
    assert {:ok, 1, 0} == DroppableQueue.pop(queue)
    assert {:ok, 2, 0} == DroppableQueue.pop(queue)
  end

  test "#push can drop from the front of the queue" do
    {:ok, queue} = DroppableQueue.start_link(max: 2, drop_end: :front)
    {:ok, 0} = DroppableQueue.push(queue, 1)
    {:ok, 0} = DroppableQueue.push(queue, 2)
    assert {:ok, 1} == DroppableQueue.push(queue, 3)
    assert {:ok, 2, 1} == DroppableQueue.pop(queue)
    assert {:ok, 3, 0} == DroppableQueue.pop(queue)
  end

  test "#push can drop from the back of the queue" do
    {:ok, queue} = DroppableQueue.start_link(max: 2, drop_end: :back)
    {:ok, 0} = DroppableQueue.push(queue, 1)
    {:ok, 0} = DroppableQueue.push(queue, 2)
    assert {:ok, 1} == DroppableQueue.push(queue, 3)
    assert {:ok, 1, 1} == DroppableQueue.pop(queue)
    assert {:ok, 2, 0} == DroppableQueue.pop(queue)
  end

  test "#push can drop using a function" do
    {:ok, queue} = DroppableQueue.start_link(max: 4, drop_end: :back)
    {:ok, 0} = DroppableQueue.push(queue, 1)
    {:ok, 0} = DroppableQueue.push(queue, 2)
    {:ok, 0} = DroppableQueue.push(queue, 3)
    {:ok, 0} = DroppableQueue.push(queue, 4)
    drop_fn = fn(a) -> rem(a, 2) == 0 end
    assert {:ok, 2} == DroppableQueue.push(queue, 5, drop_fn)

    assert {:ok, 1, 2} == DroppableQueue.pop(queue)
    assert {:ok, 3, 0} == DroppableQueue.pop(queue)
    assert {:ok, 5, 0} == DroppableQueue.pop(queue)
  end

  test "#push will drop from the specified end if the function doesn't drop enough items" do
    {:ok, queue} = DroppableQueue.start_link(max: 2, drop_end: :front)
    {:ok, 0} = DroppableQueue.push(queue, 1)
    {:ok, 0} = DroppableQueue.push(queue, 2)
    drop_fn = fn(_) -> false end
    assert {:ok, 1} == DroppableQueue.push(queue, 3, drop_fn)

    assert {:ok, 2, 1} == DroppableQueue.pop(queue)
    assert {:ok, 3, 0} == DroppableQueue.pop(queue)
  end

  test "#pop blocks the caller if the queue is empty" do
    {:ok, queue} = DroppableQueue.start_link(max: 2, drop_end: :back)
    task = Task.async(fn -> DroppableQueue.pop(queue) end)
    _ = Process.monitor(task.pid)

    :timer.sleep(10)
    DroppableQueue.push(queue, 1)
    assert {:ok, 1, 0} == Task.await(task)
  end
end

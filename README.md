# DroppableQueue

DroppableQueue is a special type of queue specially made to drop messages consistently when the queue becomes too large.
Because messages may be dropped, backpressure is not provided to the producer of the queue. However, the amount of dropped messages is forwarded to both the consumer and the producer.

## Usage

When starting a `DroppableQueue` process, you can optionally configure the max size of the queue and the end from which messages will be dropped if it becomes full.

```elixir
{:ok, queue} = DroppableQueue.start_link(max: 4, drop_end: :back)
```

With a queue started, you can add messages to it, the return value is `{:ok, num_of_dropped_messages}`

```elixir
{:ok, 0} = DroppableQueue.push(queue, 1)
{:ok, 0} = DroppableQueue.push(queue, 2)
{:ok, 0} = DroppableQueue.push(queue, 3)
{:ok, 0} = DroppableQueue.push(queue, 4)
```

When pushing messages, you can specify a function that decides which messages may be dropped. This is useful if the queue may contain duplicate messages and you want to drop duplicates only. If the function doesn't return enough items to drop, it will use the default strategy.

```elixir
drop_fn = fn(a) -> rem(a, 2) == 0 end
assert {:ok, 2} == DroppableQueue.push(queue, 5, drop_fn)

assert {:ok, 1, 2} == DroppableQueue.pop(queue)
assert {:ok, 3, 0} == DroppableQueue.pop(queue)
assert {:ok, 5, 0} == DroppableQueue.pop(queue)
```


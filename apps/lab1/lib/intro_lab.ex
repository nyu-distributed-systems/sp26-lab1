defmodule IntroLab do
  import Emulation, only: [spawn: 2, send: 2, timer: 1]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  require Fuzzers
  # This allows you to use Elixir's loggers
  # for messages. See
  # https://timber.io/blog/the-ultimate-guide-to-logging-in-elixir/
  # if you are interested in this. Note we currently purge all logs
  # below Info
  require Logger

  @moduledoc """
  All of the work on Lab 1 goes here. The TODOs
  show where code is necessary, but you will need to
  add private (defp) functions which are not included
  in order to complete the assignment.

  You **should not** change the signature of any
  public functions already defined here, and you
  should not change any functions which begin with
  the prefix `test_`.You also cannot import more
  functions from Kernel, remove any Emulation
  imports or add any more dependencies. You can
  change any of the rest of the code.
  """

  # @inc, @get and @dec are just constants we are
  # using for pedagogical convenience here.
  @inc :increment
  @dec :decrement
  @get :get

  @doc """
  A function that acts as a  counter that can be incremented
  and decremented. This function assumes a reliable network,
  and the counter's initial value is 0.

  See test_counter below for example usage.
  """
  @spec lossfree_counter() :: no_return()
  def lossfree_counter do
    lossfree_counter(0)
  end

  @spec lossfree_counter(number()) :: no_return()
  defp lossfree_counter(current) do
    receive do
      {_, @inc} ->
        # TODO: Increment counter. Do not send any messages.
        # Remember to remove this once done.
        raise "Not implemented"

      {_, @dec} ->
        # TODO: Decrement counter. Do not send any messages.
        raise "Not implemented"

      {sender, @get} ->
        send(sender, current)
        lossfree_counter(current)
    end
  end

  @doc """
  Tests the reliable counter. You cannot
  spawn this function.
  """
  @spec test_lossfree_counter() :: bool()
  def test_lossfree_counter do
    Emulation.init()

    spawn(:counter, &lossfree_counter/0)
    send(:counter, @inc)
    send(:counter, @dec)
    send(:counter, @get)

    receive do
      v -> v == 0
    end
  after
    Emulation.terminate()
  end

  # @send_timeout is the number of ms we wait for a
  # successful send in our tests.
  @send_timeout 100_000
  # @retry_timeout represents the number of ms we
  # think you should wait before retrying in a lossy
  # network. Feel free to use another value if you
  # prefer.
  @retry_timeout 100

  @doc """
  Send `message` to `destination` over a lossy
  network. The function should return once
  the message has been delivered or if timeout
  seconds have passed. Return the number of retries
  if the packet was successfully delivered, and :notok
  if the method timed out. The nonce is a number guaranteed
  to be unique for the sender, that you might find useful
  in your efforts.
  """
  @spec reliable_send(atom(), any(), number(), number()) :: integer() | :notok
  def reliable_send(destination, message, nonce, timeout) do
    # TODO: Write sender logic here. You probably want
    # to define a private function similar to what is done
    # for lossfree_counter above to keep track of the number
    # of retries.
    raise "Not implemented"
    :notok
  end

  @doc """
  The other side of `reliable_send` above. Receive
  a message, tell the sender that a packet was
  received and then return the sender and the message.
  """
  @spec reliable_receive() :: {atom(), any()}
  def reliable_receive do
    receive do
      {sender, msg} ->
        # TODO: Implement receiver logic here.
        # You might find it useful to extend the
        # `msg` part of the match out.
        raise "Not implemented"
        {sender, msg}
    end
  end

  # Use reliable_send to send a single :ping
  # message.
  @spec reliable_ping(atom()) :: number()
  defp reliable_ping(destination) do
    reliable_send(destination, :ping, 1, @send_timeout)
  end

  # Use reliable_receive to receive message from
  # reliable_ping.
  @spec reliable_ping_server() :: boolean()
  defp reliable_ping_server do
    {_, :ping} = reliable_receive()
    true
  end

  @doc """
  Test reliable send and receive using reliable_ping
  and reliable_pong.
  """
  @spec test_reliable_send_and_receive() :: boolean()
  def test_reliable_send_and_receive do
    # Initialize Emulation
    Emulation.init()

    # Add a fuzzer to drop packets
    Emulation.append_fuzzers([Fuzzers.drop(0.2), Fuzzers.delay(10.0)])
    # Start processes
    server = spawn(:server, &reliable_ping_server/0)
    spawn(:pinger, fn -> reliable_ping(:server) end)

    # Wait for pong to die. This function is running
    # **outside** of the emulation environment.
    handle = Process.monitor(server)
    Process.send_after(self(), :timeout, @send_timeout * 2)

    receive do
      {:DOWN, ^handle, _, _, _} ->
        true

      :timeout ->
        raise "Test did not finish in 60 seconds"
    end
  after
    # End emulation
    Emulation.terminate()
  end

  @doc """
  A server that runs forever, we use this for
  measuring efficiency when sending messages over
  a lossy network.
  """
  @spec test_reliable_loop_server() :: no_return()
  def test_reliable_loop_server do
    {_, :ping} = reliable_receive()
    test_reliable_loop_server()
  end

  @doc """
  Compute the median number of messages that had to be sent
  (across `count` trials) before a message was actually
  delivered. The result is sent to the `caller` as a message
  of the form `{:retries, <return>}`.
  """
  @spec get_reliable_ping_count(atom(), number(), pid()) :: boolean()
  def get_reliable_ping_count(destination, count, caller) do
    retries = measure_reliable_ping(destination, count, [])
    # This is safe as long as caller is outside emulation, we
    # do not drop packets going out.
    send(caller, {:retries, retries})
  end

  # Return the median number of attempts needed to send count
  # pings across an unreliable network.
  @spec measure_reliable_ping(atom(), number(), [number()]) :: number()
  defp measure_reliable_ping(destination, count, previous) do
    if count > 0 do
      case reliable_send(destination, :ping, count, @send_timeout) do
        :notok -> measure_reliable_ping(destination, count - 1, previous)
        m -> measure_reliable_ping(destination, count - 1, [m | previous])
      end
    else
      Statistics.median(previous)
    end
  end

  @doc """
  Measure the median number of messages (across `count` trials)
  that it takes when a network has drops messages with probability
  `drop_rate`.
  """
  @spec measure_pings_at_drop_rate(float(), number()) :: number()
  def measure_pings_at_drop_rate(drop_rate, count) do
    Emulation.init()

    Emulation.append_fuzzers([Fuzzers.drop(drop_rate), Fuzzers.delay(10.0)])
    spawn(:server, &test_reliable_loop_server/0)
    pid = self()
    spawn(:count, fn -> get_reliable_ping_count(:server, count, pid) end)

    receive do
      {:retries, count} -> count
      m -> raise "Unexpected message #{inspect(m)}"
    end
  after
    Emulation.terminate()
  end

  @doc """
  An example of how measure_pings_at_drop_rate can be used.
  """
  @spec test_measure_pings() :: number()
  def test_measure_pings do
    measure_pings_at_drop_rate(0.2, 100)
  end

  @set :set

  @doc """
  A key-value store that can work in a lossy network.
  """
  @spec reliable_kv_server() :: no_return()
  def reliable_kv_server do
    reliable_kv_server(%{}, 1)
  end

  @spec reliable_kv_server(map(), number()) :: no_return()
  defp reliable_kv_server(state, count) do
    case reliable_receive() do
      {sender, {@get, key}} ->
        # TODO: Send a message `{key, current value(key)}`
        # to the sender using `reliable_send`.
        # If the key is not currently present send
        # `{key, nil}`. You might find
        # https://hexdocs.pm/elixir/Map.html
        # useful.
        # You should use count as the nonce for
        # reliable_send, and update it each time you
        # send a message.
        raise "Not implemented"

      {_sender, {@set, key, value}} ->
        # TODO: Store  value for the given key
        # in the state. You should not send any
        # message to the sender. You might find
        # https://hexdocs.pm/elixir/Map.html
        # useful.
        raise "Not implemented"
    end
  end

  @spec test_kv_client(atom(), pid()) :: boolean()
  defp test_kv_client(server, caller) do
    reliable_send(server, {@set, :a, 1}, 1, @send_timeout)
    reliable_send(server, {@set, :b, 22}, 2, @send_timeout)
    reliable_send(server, {@get, :a}, 3, @send_timeout)

    case reliable_receive() do
      {^server, m} ->
        send(caller, m == {:a, 1})
        m == {:a, 1}

      _ ->
        send(caller, false)
        false
    end
  end

  @doc """
  Test reliable key value server.
  """
  @spec test_reliable_kv_server() :: bool()
  def test_reliable_kv_server do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.drop(0.01), Fuzzers.delay(10.0)])
    spawn(:server, &reliable_kv_server/0)
    pid = self()
    spawn(:client, fn -> test_kv_client(:server, pid) end)

    receive do
      true -> true
      _ -> false
    end
  after
    Emulation.terminate()
  end
end

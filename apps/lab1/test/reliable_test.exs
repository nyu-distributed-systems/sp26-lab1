defmodule ReliableTests do
  @moduledoc """
  """
  import Emulation, only: [spawn: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  use ExUnit.Case

  test "Test reliable ping and pong" do
    assert IntroLab.test_reliable_send_and_receive()
  end

  defp reliable_sender_timeout(dest) do
    assert IntroLab.reliable_send(dest, :ping, 1, 1000) == :notok
  end

  defp timeout_receiver(sender) do
    receive do
      {^sender, _} -> assert true
    end
  end

  test "Timeout works correctly" do
    # Initialize Emulation
    Emulation.init()

    # Add a fuzzer to drop packets
    spawn(:waiter, fn -> timeout_receiver(:sender) end)
    pong = spawn(:sender, fn -> reliable_sender_timeout(:waiter) end)

    # Wait for pong to die. This function is running
    # **outside** of the emulation environment.
    handle = Process.monitor(pong)
    Process.send_after(self(), :timeout, 60_000)

    receive do
      {:DOWN, ^handle, _, _, _} ->
        true

      :timeout ->
        raise "Test did not finish in 60 seconds"
    end
  after
    Emulation.terminate()
  end

  defp reliable_sender_count(dest) do
    assert IntroLab.reliable_send(dest, :ping, 1, 1000) == 1
  end

  defp reliable_receiver(src) do
    case IntroLab.reliable_receive() do
      {^src, :ping} ->
        true

      m ->
        assert(false, "Expected :ping from #{inspect(src)} got #{inspect(m)}")
    end
  end

  test "Send counts are correct" do
    Emulation.init()

    spawn(:waiter, fn -> reliable_receiver(:sender) end)
    pong = spawn(:sender, fn -> reliable_sender_count(:waiter) end)

    handle = Process.monitor(pong)
    Process.send_after(self(), :timeout, 60_000)

    receive do
      {:DOWN, ^handle, _, _, _} ->
        true

      :timeout ->
        raise "Test did not finish in 60 seconds"
    end
  after
    Emulation.terminate()
  end

  test "Send counts are sensible" do
    Emulation.init()

    Emulation.append_fuzzers([Fuzzers.delay(10.0)])
    spawn(:server, &IntroLab.test_reliable_loop_server/0)
    pid = self()

    spawn(:count, fn -> IntroLab.get_reliable_ping_count(:server, 10, pid) end)

    receive do
      {:retries, count} -> assert count <= 10
      _ -> raise "Unexpected message"
    end
  after
    Emulation.terminate()
  end
end

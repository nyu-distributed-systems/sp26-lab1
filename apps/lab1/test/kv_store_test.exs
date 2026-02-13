defmodule KVStoreTests do
  @moduledoc """
  Tests the reliable_kv_server function. You may add,
  but not modify,  tests to this file.
  """
  import Emulation, only: [spawn: 2, send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  use ExUnit.Case

  test "Test KV server" do
    assert IntroLab.test_reliable_kv_server()
  end

  @send_timeout 100_000

  defp test_kv_client(server, caller) do
    IntroLab.reliable_send(server, {:set, :a, 1}, 1, @send_timeout)
    IntroLab.reliable_send(server, {:set, :b, 22}, 2, @send_timeout)
    IntroLab.reliable_send(server, {:get, :a}, 3, @send_timeout)

    case IntroLab.reliable_receive() do
      {^server, m} -> assert m == {:a, 1}
      _ -> assert false
    end

    IntroLab.reliable_send(server, {:get, :b}, 4, @send_timeout)

    case IntroLab.reliable_receive() do
      {^server, m} -> assert m == {:b, 22}
      _ -> assert false
    end

    send(caller, true)
  end

  test "Test multiple gets" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.drop(0.01), Fuzzers.delay(10.0)])
    spawn(:server, &IntroLab.reliable_kv_server/0)
    pid = self()
    spawn(:client, fn -> test_kv_client(:server, pid) end)

    receive do
      true -> true
      _ -> assert false
    end
  after
    Emulation.terminate()
  end
end

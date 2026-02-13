defmodule LossfreeCounterTests do
  @moduledoc """
  Tests the lossfree_counter function. You may add,
  but not modify,  tests to this file.
  """
  import Emulation, only: [spawn: 2, send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  use ExUnit.Case
  doctest IntroLab

  test "runs test_lossfree_counter" do
    assert IntroLab.test_lossfree_counter()
  end

  test "check that increments work" do
    Emulation.init()

    spawn(:counter, &IntroLab.lossfree_counter/0)
    send(:counter, :get)

    receive do
      v -> assert v == 0
    end

    send(:counter, :increment)
    send(:counter, :get)

    receive do
      v -> assert v == 1
    end
  after
    Emulation.terminate()
  end

  test "check that repeated gets work work" do
    Emulation.init()

    spawn(:counter, &IntroLab.lossfree_counter/0)
    send(:counter, :get)

    receive do
      v -> assert v == 0
    end

    send(:counter, :increment)
    send(:counter, :get)

    receive do
      v -> assert v == 1
    end

    send(:counter, :get)

    receive do
      v -> assert v == 1
    end

    send(:counter, :get)

    receive do
      v -> assert v == 1
    end
  after
    Emulation.terminate()
  end

  test "Check that decrements work" do
    Emulation.init()

    spawn(:counter, &IntroLab.lossfree_counter/0)
    send(:counter, :get)

    receive do
      v -> assert v == 0
    end

    send(:counter, :decrement)
    send(:counter, :get)

    receive do
      v -> assert v == -1
    end

    send(:counter, :increment)
    send(:counter, :get)

    receive do
      v -> assert v == 0
    end
  after
    Emulation.terminate()
  end
end

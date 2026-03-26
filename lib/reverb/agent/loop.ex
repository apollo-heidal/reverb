defmodule Reverb.Agent.Loop do
  @moduledoc """
  GenServer that continuously processes Reverb tasks by spawning an
  external agent (e.g., Claude CLI) via an Erlang Port.

  Adapted from the heartbeat system. Features:
  - Serial task processing (no concurrent agents)
  - Priority: :worked_on > :todo > :new
  - Circuit breaker with exponential backoff
  - Idle rotation when task queue is empty
  - Pause/resume API
  """

  use GenServer
  require Logger

  alias Reverb.{Tasks, Agent.Runner, Agent.Rotation}

  @default_config %{
    enabled: false,
    boot_delay_ms: 30_000,
    cooldown_ms: 30_000,
    idle_rotation_ms: 900_000,
    task_timeout_ms: 600_000,
    max_consecutive_failures: 3,
    backoff_base_ms: 120_000,
    backoff_max_ms: 900_000,
    agent_command: "claude",
    agent_args: ["--dangerously-skip-permissions", "--print"],
    project_root: nil
  }

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the current agent loop status."
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc "Pauses the agent loop."
  def pause do
    GenServer.call(__MODULE__, :pause)
  end

  @doc "Resumes the agent loop."
  def resume do
    GenServer.call(__MODULE__, :resume)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    config = load_config()

    state = %{
      status: :booting,
      current_task_id: nil,
      current_task_body: nil,
      port: nil,
      consecutive_failures: 0,
      last_completed_at: nil,
      started_at: DateTime.utc_now(),
      output_buffer: "",
      rotation_index: 0,
      loop_timer_ref: nil,
      timeout_timer_ref: nil,
      config: config
    }

    if config.enabled do
      Logger.info("[Reverb.Loop] Starting, first loop in #{config.boot_delay_ms}ms")
      ref = Process.send_after(self(), :loop, config.boot_delay_ms)
      {:ok, %{state | loop_timer_ref: ref}}
    else
      Logger.info("[Reverb.Loop] Started in disabled mode")
      {:ok, %{state | status: :disabled}}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    reply = %{
      alive: true,
      status: state.status,
      current_task_id: state.current_task_id,
      current_task_body: state.current_task_body,
      consecutive_failures: state.consecutive_failures,
      last_completed_at: state.last_completed_at,
      rotation_index: state.rotation_index,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at, :second)
    }

    {:reply, reply, state}
  end

  def handle_call(:pause, _from, state) do
    state = cancel_timer(state, :loop_timer_ref)
    state = %{state | status: :paused}
    Logger.info("[Reverb.Loop] Paused")
    {:reply, :ok, state}
  end

  def handle_call(:resume, _from, state) do
    if state.status == :paused do
      Logger.info("[Reverb.Loop] Resumed")
      ref = Process.send_after(self(), :loop, 0)
      {:reply, :ok, %{state | status: :idle, loop_timer_ref: ref}}
    else
      {:reply, {:error, :not_paused}, state}
    end
  end

  @impl true
  def handle_info(:loop, %{status: :paused} = state) do
    {:noreply, state}
  end

  def handle_info(:loop, state) do
    state = %{state | loop_timer_ref: nil}

    case pick_task() do
      {:ok, task} ->
        Logger.info("[Reverb.Loop] Picked task #{task.id}: #{String.slice(task.body, 0, 80)}")
        Tasks.update_status(task.id, :worked_on)

        prompt = build_task_prompt(task)
        {port, timeout_ref} = Runner.open_port(prompt, state.config)

        state = %{state |
          status: :running,
          current_task_id: task.id,
          current_task_body: task.body,
          port: port,
          output_buffer: "",
          timeout_timer_ref: timeout_ref
        }

        {:noreply, state}

      :empty ->
        Logger.debug("[Reverb.Loop] Queue empty, rotation item #{state.rotation_index}")
        prompt = build_rotation_prompt(state.rotation_index)
        next_index = rem(state.rotation_index + 1, Rotation.count())
        {port, timeout_ref} = Runner.open_port(prompt, state.config)

        state = %{state |
          status: :running,
          current_task_id: nil,
          current_task_body: "rotation",
          rotation_index: next_index,
          port: port,
          output_buffer: "",
          timeout_timer_ref: timeout_ref
        }

        {:noreply, state}
    end
  end

  # Port stdout
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {:noreply, %{state | output_buffer: Runner.append_buffer(state.output_buffer, data)}}
  end

  # Port exit — success
  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    state = cancel_timer(state, :timeout_timer_ref)
    Logger.info("[Reverb.Loop] Agent exited successfully")

    if state.current_task_id do
      Tasks.update_status(state.current_task_id, :done)
    end

    delay = if state.current_task_id, do: state.config.cooldown_ms, else: state.config.idle_rotation_ms
    ref = Process.send_after(self(), :loop, delay)

    state = %{state |
      status: :idle, port: nil, current_task_id: nil, current_task_body: nil,
      output_buffer: "", consecutive_failures: 0,
      last_completed_at: DateTime.utc_now(), loop_timer_ref: ref
    }

    {:noreply, state}
  end

  # Port exit — failure
  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    state = cancel_timer(state, :timeout_timer_ref)
    failures = state.consecutive_failures + 1
    Logger.warning("[Reverb.Loop] Agent exited with code #{code} (failure #{failures})")

    {next_status, delay} =
      if failures >= state.config.max_consecutive_failures do
        backoff = backoff_delay(failures, state.config)
        Logger.warning("[Reverb.Loop] Circuit breaker: backing off #{backoff}ms")
        {:backoff, backoff}
      else
        {:idle, state.config.cooldown_ms}
      end

    ref = Process.send_after(self(), :loop, delay)

    state = %{state |
      status: next_status, port: nil, current_task_id: nil, current_task_body: nil,
      output_buffer: "", consecutive_failures: failures, loop_timer_ref: ref
    }

    {:noreply, state}
  end

  # Task timeout
  def handle_info(:task_timeout, %{port: port, status: :running} = state) when not is_nil(port) do
    Logger.warning("[Reverb.Loop] Task timed out, killing port")
    Runner.close_port(port)
    {:noreply, %{state | timeout_timer_ref: nil}}
  end

  def handle_info(:task_timeout, state) do
    {:noreply, %{state | timeout_timer_ref: nil}}
  end

  # Catch-all for stale port messages
  def handle_info({port, _}, state) when is_port(port) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{port: port}) when not is_nil(port) do
    Runner.close_port(port)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  # --- Private ---

  defp load_config do
    app_config =
      Application.get_env(:reverb, Reverb.Agent, [])
      |> Map.new()

    config = Map.merge(@default_config, app_config)
    %{config | project_root: config.project_root || File.cwd!()}
  end

  defp pick_task do
    with [] <- Tasks.list_by_status(:worked_on, limit: 1),
         [] <- Tasks.list_by_status(:todo, limit: 1),
         [] <- Tasks.list_by_status(:new, limit: 1) do
      :empty
    else
      [task | _] -> {:ok, task}
    end
  end

  defp build_task_prompt(task) do
    """
    Read HEARTBEAT.md (project root) if it exists. Follow it strictly.

    YOUR TASK (Reverb Task ID #{task.id}):
    #{task.body}

    When done, Reverb will mark this task as :done automatically.
    Just do the work and commit. Keep log output minimal.
    """
  end

  defp build_rotation_prompt(index) do
    activity = Rotation.at(index)

    """
    Read HEARTBEAT.md (project root) if it exists. Follow it strictly.

    The task queue is empty. Perform this rotation activity:
    #{activity}

    If nothing needs attention, reply HEARTBEAT_OK.
    Keep log output minimal.
    """
  end

  defp cancel_timer(state, key) do
    case Map.get(state, key) do
      nil -> state
      ref -> Process.cancel_timer(ref); Map.put(state, key, nil)
    end
  end

  defp backoff_delay(failures, config) do
    exponent = failures - config.max_consecutive_failures
    delay = config.backoff_base_ms * :math.pow(2, exponent)
    min(round(delay), config.backoff_max_ms)
  end
end

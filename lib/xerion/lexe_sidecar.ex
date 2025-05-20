defmodule Xerion.LexeSidecar do
  use GenServer
  require Logger

  @api_url "http://localhost:5393"
  @max_retries 30
  @retry_delay 1000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Get the sidecar path from environment variable
    # This allows users to specify a custom path without modifying the code
    case System.get_env("LEXE_SIDECAR_PATH") do
      nil ->
        Logger.error("LEXE_SIDECAR_PATH environment variable is not set")
        {:stop, :missing_sidecar_path}
      sidecar_path ->
        port = Port.open({:spawn, sidecar_path}, [:binary, :exit_status, {:line, 1024}])
        state = %{port: port, ready: false}
        Process.send_after(self(), :check_health, 1000)
        {:ok, state}
    end
  end

  @impl true
  def handle_info({_port, {:data, {:eol, line}}}, state) do
    Logger.info("Lexe sidecar: #{line}")
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.error("Lexe sidecar exited with status #{status}")
    {:noreply, state}
  end

  def handle_info(:check_health, state) do
    case check_health() do
      :ok ->
        Logger.info("Lexe sidecar is ready")
        {:noreply, %{state | ready: true}}
      :error ->
        if state.retries < @max_retries do
          Process.send_after(self(), :check_health, @retry_delay)
          {:noreply, %{state | retries: (state.retries || 0) + 1}}
        else
          Logger.error("Lexe sidecar failed to become ready after #{@max_retries} attempts")
          {:noreply, state}
        end
    end
  end

  def create_invoice(amount, description) do
    if GenServer.call(__MODULE__, :is_ready?) do
      body = Jason.encode!(%{
        expiration_secs: 3600,
        amount: to_string(amount),
        description: description
      })

      case HTTPoison.post("#{@api_url}/v1/node/create_invoice", body, [{"Content-Type", "application/json"}], timeout: 15_000, recv_timeout: 15_000) do
        {:ok, %{status_code: 200, body: body}} ->
          {:ok, Jason.decode!(body)}
        {:ok, %{status_code: status, body: body}} ->
          {:error, "Failed to create invoice: #{status} - #{body}"}
        {:error, reason} ->
          {:error, "Failed to create invoice: #{inspect(reason)}"}
      end
    else
      {:error, "Lexe sidecar is not ready yet"}
    end
  end

  def get_payment_status(index) do
    if GenServer.call(__MODULE__, :is_ready?) do
      case HTTPoison.get("#{@api_url}/v1/node/payment?index=#{index}", [], timeout: 15_000, recv_timeout: 15_000) do
        {:ok, %{status_code: 200, body: body}} ->
          {:ok, Jason.decode!(body)}
        {:ok, %{status_code: status, body: body}} ->
          {:error, "Failed to get payment status: #{status} - #{body}"}
        {:error, reason} ->
          {:error, "Failed to get payment status: #{inspect(reason)}"}
      end
    else
      {:error, "Lexe sidecar is not ready yet"}
    end
  end

  @impl true
  def handle_call(:is_ready?, _from, state) do
    {:reply, state.ready, state}
  end

  defp check_health do
    case HTTPoison.get("#{@api_url}/v1/health", [], timeout: 5_000, recv_timeout: 5_000) do
      {:ok, %{status_code: 200}} -> :ok
      _ -> :error
    end
  end
end

defmodule Xerion.WebServer do
  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  def start_link(_) do
    port = Application.get_env(:xerion, :port, 8080)
    {:ok, _} = Plug.Cowboy.http(__MODULE__, [], port: port)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  get "/" do
    html = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>Lightning Tip</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
            text-align: center;
          }
          .tip-button {
            background-color: #4CAF50;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
            border-radius: 4px;
          }
          .qr-container {
            margin: 2rem auto;
            max-width: 300px;
          }
          .success {
            color: #4CAF50;
            font-size: 24px;
            margin: 2rem 0;
          }
          .error {
            color: #f44336;
            margin: 1rem 0;
          }
        </style>
      </head>
      <body>
        <h1>Support Our Work</h1>
        <p>Send a Lightning payment to support our work!</p>
        <button class="tip-button" onclick="createInvoice()">Send Tip</button>
        <div id="qr-container" class="qr-container"></div>
        <div id="status"></div>
        <script src="https://cdn.jsdelivr.net/npm/canvas-confetti@1.6.0/dist/confetti.browser.min.js"></script>
        <script>
          let paymentIndex = null;
          let pollInterval = null;
          let jsConfetti = null;

          // Initialize confetti after the script is loaded
          window.addEventListener('load', function() {
            jsConfetti = new JSConfetti();
          });

          async function createInvoice() {
            try {
              const response = await fetch('/create_invoice', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                  amount: 1000,
                  description: 'Tip'
                })
              });
              const data = await response.json();

              if (data.error) {
                document.getElementById('status').innerHTML = `<div class="error">${data.error}</div>`;
                return;
              }

              paymentIndex = data.index;
              document.getElementById('qr-container').innerHTML = `<img src="data:image/png;base64,${data.qr_code}" alt="Lightning QR Code">`;
              document.getElementById('status').innerHTML = '<div>Scan the QR code to pay</div>';

              // Start polling for payment status
              if (pollInterval) clearInterval(pollInterval);
              pollInterval = setInterval(checkPaymentStatus, 2000);
            } catch (error) {
              document.getElementById('status').innerHTML = `<div class="error">Failed to create invoice: ${error}</div>`;
            }
          }

          async function checkPaymentStatus() {
            if (!paymentIndex) return;

            try {
              const response = await fetch(`/payment_status?index=${paymentIndex}`);
              const data = await response.json();

              if (data.error) {
                document.getElementById('status').innerHTML = `<div class="error">${data.error}</div>`;
                clearInterval(pollInterval);
                return;
              }

              if (data.payment.status === 'completed') {
                clearInterval(pollInterval);
                document.getElementById('qr-container').innerHTML = '';
                document.getElementById('status').innerHTML = '<div class="success">Payment received! Thank you! 🎉</div>';
                // Show confetti
                if (jsConfetti) {
                  jsConfetti.addConfetti();
                }
              } else if (data.payment.status === 'failed') {
                clearInterval(pollInterval);
                document.getElementById('status').innerHTML = '<div class="error">Payment failed</div>';
              }
            } catch (error) {
              document.getElementById('status').innerHTML = `<div class="error">Failed to check payment status: ${error}</div>`;
              clearInterval(pollInterval);
            }
          }
        </script>
      </body>
    </html>
    """
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  post "/create_invoice" do
    {:ok, body, conn} = read_body(conn)
    params = Jason.decode!(body)

    case Xerion.LexeSidecar.create_invoice(params["amount"], params["description"]) do
      {:ok, invoice} ->
        # Generate QR code
        qr = EQRCode.encode(invoice["invoice"])
        png = EQRCode.png(qr)
        qr_base64 = Base.encode64(png)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{
          index: invoice["index"],
          qr_code: qr_base64
        }))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: reason}))
    end
  end

  get "/payment_status" do
    index = conn.query_string
    |> URI.decode_query()
    |> Map.get("index")

    case Xerion.LexeSidecar.get_payment_status(index) do
      {:ok, response} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: reason}))
    end
  end

  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end
end

# Xerion - Lightning Tip Page

A simple web service that allows visitors to send Lightning payments. Built with Elixir and the Lexe API.

## Prerequisites

- Elixir 1.18.3
- OTP 27
- Lexe sidecar binary

## Environment Variables

The application uses a `.env` file for configuration. Copy `env.example` to `.env` and modify the values:

```bash
cp env.example .env
```

Required environment variables:
- `LEXE_SIDECAR_PATH`: Path to the Lexe sidecar binary

## Installation

1. Install dependencies:
   ```bash
   mix deps.get
   ```

2. Start the application:
   ```bash
   mix run --no-halt
   ```

The web server will start on port 8080. Visit http://localhost:8080 to see the tip page.

## Features

- Simple and clean UI for sending Lightning payments
- QR code generation for easy mobile scanning
- Real-time payment status updates
- Confetti animation on successful payment
- Automatic Lexe sidecar management

## API Endpoints

- `GET /` - Serves the tip page
- `POST /create_invoice` - Creates a new Lightning invoice
- `GET /payment_status` - Checks the status of a payment 
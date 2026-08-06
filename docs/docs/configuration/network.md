# Network Configuration

Configure the gateway's network settings.

## Port

Default: `2525`

The gateway listens on this port for all API requests. Change it if you have a port conflict.

## Bind host

Default: `127.0.0.1`

- `127.0.0.1` — accessible only from this machine (recommended for security).
- `0.0.0.0` — accessible from other devices on your network.

## Allowed origins (CORS)

Default: `*`

Comma-separated list of origins allowed to make cross-origin requests. `*` allows all origins — suitable for local development.

## API key

When set, all requests must include `Authorization: Bearer <api-key>`. This protects your local gateway from unauthorised access.

- **Auto-generated**: a key like `sk-mlx-<uuid>` is created on first launch.
- **Rotate**: click **Regenerate** to create a new key.
- **Required by** integrations — the Apply button in the Integrations tab automatically configures clients to send this key.

## Cloudflare Tunnel

Toggle **Enable Tunnel** to create a public `trycloudflare.com` URL that forwards to your local gateway. This allows:

- Accessing your models from anywhere
- Sharing a temporary URL with collaborators
- Using your gateway from services that require a public endpoint

The tunnel URL appears in the UI once active.

# Frisbii Credentials

## Required Credentials

To use Frisbii with Pay, you'll need:

1. **Private API Key** (required) - For server-side API calls
2. **Public API Key** (optional) - For client-side integrations
3. **Webhook Signing Secret** (required for webhooks) - To verify webhook authenticity

## Configuration Methods

### Method 1: Rails Credentials (Recommended)

Edit your Rails credentials:

```bash
rails credentials:edit
```

Add your Frisbii credentials:

```yaml
frisbii:
  private_key: priv_your_private_api_key_here
  public_key: pub_your_public_api_key_here  # Optional
  signing_secret: your_webhook_signing_secret_here
```

### Method 2: Environment Variables

Set these environment variables in your deployment:

```bash
export FRISBII_PRIVATE_KEY="priv_your_private_api_key_here"
export FRISBII_PUBLIC_KEY="pub_your_public_api_key_here"  # Optional
export FRISBII_SIGNING_SECRET="your_webhook_signing_secret_here"
```

For development, add to `.env`:

```bash
FRISBII_PRIVATE_KEY=priv_test_key
FRISBII_PUBLIC_KEY=pub_test_key
FRISBII_SIGNING_SECRET=test_webhook_secret
```

### Method 3: Manual Configuration

Configure directly in an initializer:

```ruby
# config/initializers/pay.rb
Pay::Frisbii.private_key = ENV.fetch("CUSTOM_FRISBII_KEY")
Pay::Frisbii.public_key = ENV["CUSTOM_FRISBII_PUBLIC_KEY"]
Pay::Frisbii.signing_secret = Rails.application.secrets.frisbii_webhook_secret
```

## Configuration Hierarchy

The gem checks for credentials in this order:

1. Rails credentials (`rails credentials:edit`)
2. Environment variables (as fallback)
3. Manual assignment (if explicitly set in code)

## Obtaining Credentials

1. Log into your [Frisbii Dashboard](https://app.frisbii.com)
2. Navigate to **Settings** → **API Keys**
3. Generate or copy your private key
4. For webhooks, go to **Settings** → **Webhooks** to get the signing secret

## Test vs Production

Frisbii uses the same API endpoint for test and production. Use test API keys during development:

- Test keys start with `priv_test_`
- Production keys start with `priv_live_`

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use Rails credentials** for production
3. **Rotate keys regularly** through the Frisbii dashboard
4. **Restrict API key permissions** when possible
5. **Keep webhook secret confidential** to prevent webhook spoofing

## Verifying Configuration

Check if credentials are loaded correctly:

```ruby
# Rails console
Pay::Frisbii.private_key
# => "priv_..."

Pay::Frisbii.signing_secret
# => "whsec_..."
```

## Troubleshooting

If credentials aren't loading:

1. Check Rails credentials are saved: `rails credentials:show`
2. Verify environment variables: `ENV["FRISBII_PRIVATE_KEY"]`
3. Ensure Pay is configured: `Pay.enabled_processors.include?(:frisbii)`
4. Check for typos in credential keys

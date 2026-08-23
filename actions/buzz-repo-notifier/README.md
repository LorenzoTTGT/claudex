# Buzz Repository Notifier

A reusable JavaScript action that posts repository activity to a [Buzz](https://github.com/block/buzz) channel. It supports GitHub Actions and Forgejo Actions without downloading the Buzz desktop application.

## Events

- Push to `main`
- Issue opened
- Pull request opened

Pull request merges are represented by the resulting `main` push, so they are not posted separately. Other branch pushes and closed pull requests are ignored to keep the Buzz channel readable.

## Usage

```yaml
name: Notify Buzz

on:
  push:
    branches: [main]
  issues:
    types: [opened]
  pull_request:
    types: [opened]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: LorenzoTTGT/buzz-repo-notifier@REPLACE_WITH_COMMIT_SHA
        with:
          relay_url: ${{ vars.BUZZ_RELAY_URL }}
          channel_id: ${{ vars.BUZZ_CHANNEL_ID }}
          channel_name: ${{ vars.BUZZ_CHANNEL_NAME }}
          private_key: ${{ secrets.BUZZ_PRIVATE_KEY }}
```

Configure these repository values:

| Type | Name | Example |
| --- | --- | --- |
| Variable | `BUZZ_RELAY_URL` | `https://buzz.example.com` |
| Variable | `BUZZ_CHANNEL_NAME` | Optional. Defaults to the repository full name. |
| Variable | `BUZZ_CHANNEL_ID` | Optional existing Buzz channel UUID. Overrides `BUZZ_CHANNEL_NAME` when set. |
| Secret | `BUZZ_PRIVATE_KEY` | Dedicated bot key in hex or `nsec` form |

When `BUZZ_CHANNEL_ID` is omitted, the action finds a channel by `BUZZ_CHANNEL_NAME` and creates an open channel if it does not exist. The Buzz identity signs the channel lookup, creation, and notification events. Use a separate identity with the `bot` role for repository notifications; never use a human owner or administrator key.

## Installer

From a local checkout of the repository you want to notify, run the installer with the GitHub CLI authenticated:

```bash
BUZZ_PRIVATE_KEY='nsec-or-hex-bot-key' npx github:LorenzoTTGT/buzz-repo-notifier \
  --repo OWNER/REPO \
  --relay-url https://buzz.example.com \
  --channel-name buzz-repo-notifier \
  --action LorenzoTTGT/buzz-repo-notifier@FULL_COMMIT_SHA \
  --commit --push
```

The installer writes `.github/workflows/notify-buzz.yml`, sets `BUZZ_RELAY_URL` and optional `BUZZ_CHANNEL_NAME`/`BUZZ_CHANNEL_ID` as repository variables, and sets `BUZZ_PRIVATE_KEY` as an Actions secret. If neither channel value is configured, notifications use the repository full name as the Buzz channel name and create it on first use when missing. Pass `--channel-id BUZZ_CHANNEL_UUID` to force an existing channel. Omit `--commit --push` if you want to inspect the generated workflow before publishing it.

Use `--private-key-stdin` instead of `BUZZ_PRIVATE_KEY=...` when you do not want the key in your shell history:

```bash
printf '%s' "$BUZZ_PRIVATE_KEY" | npx github:LorenzoTTGT/buzz-repo-notifier \
  --repo OWNER/REPO \
  --relay-url https://buzz.example.com \
  --channel-name buzz-repo-notifier \
  --action LorenzoTTGT/buzz-repo-notifier@FULL_COMMIT_SHA \
  --private-key-stdin
```

## Security

- Pin this action to a full commit SHA in production workflows.
- The bundled action does not check out or execute code from the application repository.
- Store the signing key only as an Actions secret.
- Give each repository its own low-privilege Buzz bot identity so a compromised repository cannot impersonate other integrations.
- GitHub does not provide Actions secrets to workflows triggered from forks by default. Review the equivalent policy on your Forgejo installation.

## Development

```bash
npm ci
npm test
npm run build
```

Commit changes under `dist/` because JavaScript actions execute the bundled entry point.

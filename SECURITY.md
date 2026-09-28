# Security

MISHIRUBE has no account system, no backend of its own and no
telemetry. Records live on the device; this page lists what the app
holds and every case in which something leaves the device.

## What the app holds

An SQLite database in the app's own container: what was trained, eaten,
drunk, weighed and slept, plus an audit trail of every change. Deleted
records are kept as tombstones, so a deletion can be undone. On iOS and
Android the container is protected by the OS and the device passcode.

API keys and sign-in tokens for AI providers are kept in the Keychain
(iOS) or the Keystore (Android), not in the database.

## What leaves the device

Each of these happens only after the user turns it on.

### Apple Health and Health Connect

Once connected, the app reads the kinds the user allowed from Apple
Health or Health Connect, and writes to it what is logged in the app:
weight, body figures, waist, sleep, workouts, meals, water and mood.
Records written by the app are updated or removed on the platform when
they are edited or deleted in the app. Imported platform records are
never written back.

The platform is part of the operating system. What it does with the
data — including Apple's own iCloud sync of Health data — is governed
by Apple's and Google's terms, not by this app.

### AI providers

- **Apple Intelligence** is used, without asking, when it is on and no
  other provider is chosen. A request goes to Apple's Private Cloud
  Compute when it is available, and to the on-device model otherwise.
  Photos are handed over as pixels only, without location or capture
  metadata.
- **A cloud provider** (Ollama Cloud, Google AI Studio, Anthropic, Azure
  AI Foundry, an OpenAI-compatible address, Microsoft 365 Copilot) is
  off until chosen. The app asks for consent before the first text is
  sent to it, and again before the first photo. What is sent is the
  text or photo of that request, with location and capture metadata
  stripped from photos, under that provider's terms. Consent can be
  withdrawn from *Me → AI*.

Requests go from the device straight to the provider. The app does not
proxy anything, because there is no server of its own to proxy through.

### Maps

A workout's route is drawn on map tiles fetched from MapKit (iOS) or
MapLibre (Android) when the route is opened. The route itself is not
sent, but the tiles requested show the map service the area it covers.

## Exports

Export writes a file the user chooses to keep. From that moment the
file is an ordinary document with a health history in it — it is not
encrypted, and it is as private as wherever it is put.

Settings whose key begins with `secret.` are left out of every export,
and a restore does not delete them. `test/secrets_test.dart` checks
this, and that no credential-shaped literal is in the source, rather
than trusting it.

## Reporting a problem

Open a private security advisory on the repository, or contact the
maintainer directly. Please do not open a public issue for something
that would put other people's data at risk before it is fixed.

Useful things to include: what the app did, what was expected, and
whether the data involved was the reporter's own or came from an
import.

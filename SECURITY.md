# Security

MISHIRUBE keeps everything on the device. There is no account, no
server and no telemetry, so most of what a security policy usually
covers does not exist here. What follows is what does.

## What the app holds

An SQLite database in the app's own container: what you trained, ate,
drank and weighed, plus an audit trail of every change. On iOS and
Android that container is protected by the OS and the device passcode.
Nothing is sent anywhere.

## Exports

Export writes a file you choose to keep. From that moment the file is
an ordinary document with your health history in it — it is not
encrypted, and it is as private as wherever you put it.

Settings whose key begins with `secret.` are deliberately left out of
every export, and a restore does not delete them. This is where an API
key for an AI provider goes, so that a backup you email yourself does
not carry your credentials with it. `test/secrets_test.dart` checks
this rather than trusting it.

## AI providers

Any AI feature is bring-your-own-key and off until you turn it on.
Turning it on means your own text or photograph leaves the device for
the provider you chose, under that provider's terms. The app does not
proxy anything through us, because there is no us to proxy through.

## Reporting a problem

Open a private security advisory on the repository, or contact the
maintainer directly. Please do not open a public issue for something
that would put other people's data at risk before it is fixed.

Useful things to include: what the app did, what you expected, and
whether the data involved was yours or came from an import.

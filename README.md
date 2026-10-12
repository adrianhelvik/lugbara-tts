# Lugbara

A macOS menu bar app that reads the selected text aloud with OpenAI's voices. Select text in any app and press **⌥ Option + Esc**. Press it again to stop.

It reads Norwegian and English, and picks the language by itself. Code in the text is described in a sentence or skipped, so a reply from a coding assistant sounds like speech, not like symbols.

## What you need

- macOS 14 or later
- Xcode or the Xcode command line tools, to build it
- An OpenAI API key from [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

## Install

```sh
git clone https://github.com/adrianhelvik/lugbara-tts.git
cd lugbara-tts
scripts/create-signing-certificate.sh   # optional, see below
make install
```

`make install` builds the app, copies it to `/Applications` and starts it. On first start, Lugbara asks for two things:

1. **Your OpenAI API key.** It is stored in your login keychain.
2. **Accessibility permission**, in System Settings → Privacy & Security → Accessibility. Lugbara needs it to read the selected text in other apps.

### Why the signing certificate

macOS remembers the Accessibility permission for one exact build of an app. Without a certificate, it asks again every time you rebuild. `scripts/create-signing-certificate.sh` creates a self-signed certificate called "Lugbara Local" in your login keychain, and `make` signs every build with it. The certificate only works on your Mac.

## Use

- **⌥ Option + Esc** reads the selection, or stops reading.
- **The menu bar icon** opens a panel with the language, voice and speed, and a switch for how code is read.

## How it reads

1. Lugbara reads the selection through the Accessibility API. When an app does not support that, it presses ⌘C and puts your clipboard back afterwards.
2. The first paragraph is spoken right away. Meanwhile, `gpt-6-luna` rewrites the rest for listening: prose stays word for word, code becomes a short description, and file paths become file names.
3. If Luna is off, slow or fails, fixed rules do the cleanup instead, and code is read as "Code block".
4. The text goes to OpenAI's speech endpoint (`gpt-4o-mini-tts`) in short pieces. Audio plays while it downloads.

## Cost and privacy

- Speech costs about **$0.015 per minute** of audio, on your own OpenAI account. The Luna rewrite costs a fraction of that.
- The selected text is sent to OpenAI. Lugbara asks OpenAI not to store the Luna request (`store: false`). Nothing else leaves your Mac.

## Develop

```sh
make test      # unit tests for the text cleanup
make run       # build and start from build/, without installing
```

The code is in `Sources/Lugbara`. `Speaker.swift` is the place to start.

## License

MIT

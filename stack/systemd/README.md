# systemd user services

These units are templates for manual user services. Copy them into the user
systemd unit directory, reload systemd, then start them explicitly.

```sh
mkdir -p ~/.config/systemd/user
cp stack/systemd/llama-gemma.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user start llama-gemma.service
systemctl --user status llama-gemma.service
```

Follow logs with:

```sh
journalctl --user -u llama-gemma.service -f
```

Stop the service with:

```sh
systemctl --user stop llama-gemma.service
```

Do not run `systemctl --user enable llama-gemma.service` unless you want it to
start automatically with the user session.

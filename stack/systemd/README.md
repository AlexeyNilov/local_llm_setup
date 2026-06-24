# systemd user services

These units are templates for manual user services. Copy them into the user
systemd unit directory, reload systemd, then start them explicitly.

```sh
mkdir -p ~/.config/systemd/user
cp stack/systemd/qdrant.service ~/.config/systemd/user/
cp stack/systemd/llama-gemma.service ~/.config/systemd/user/
cp stack/systemd/llama-agentic-gemma.service ~/.config/systemd/user/
cp stack/systemd/llama-jina.service ~/.config/systemd/user/
cp stack/systemd/llm-stack.target ~/.config/systemd/user/
systemctl --user daemon-reload
```

Start the whole stack explicitly:

```sh
systemctl --user start llm-stack.target
systemctl --user status llm-stack.target
```

Start a service explicitly:

```sh
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

Use `llama-jina.service` and `qdrant.service` in the same commands for the Jina
embedding server and Qdrant. Use `llama-agentic-gemma.service` for the agentic
Gemma server.

Qdrant is started through Docker. Because user services cannot prompt for a sudo
password, `qdrant.service` expects `sudo -n docker ...` to work or it will fail.
If that is not true on this machine, use rootless Docker, add your user to the
Docker group, or configure a narrowly scoped sudoers rule for Docker.

Do not run `systemctl --user enable ...` unless you want a service to start
automatically with the user session.

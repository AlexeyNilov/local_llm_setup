```sh
docker run -d --device /dev/kfd --device /dev/dri -v ollama:/root/.ollama -p 11434:11434 --name ollama-gpu --restart unless-stopped ollama/ollama:rocm
```
docker pull ollama/ollama:rocm
docker stop ollama-gpu
docker rm ollama-gpu
docker run -d \
  --device /dev/kfd \
  --device /dev/dri \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --name ollama-gpu \
  --restart unless-stopped \
  ollama/ollama:rocm
docker exec ollama-gpu ollama --version
docker exec ollama-gpu ollama list

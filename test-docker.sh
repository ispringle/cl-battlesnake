#!/bin/bash
# Test script for Docker deployment
# Usage: ./test-docker.sh [snake-class]
# Example: ./test-docker.sh cautious-snake

set -e

SNAKE_CLASS="${1:-random-snake}"
PORT=8080
IMAGE_NAME="cl-battlesnake-test"

echo "================================="
echo "Testing Docker deployment"
echo "Snake: $SNAKE_CLASS"
echo "================================="

# Build the image
echo ""
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" --build-arg SNAKE_CLASS="$SNAKE_CLASS" .

echo ""
echo "Starting container..."
CONTAINER_ID=$(docker run -d -p $PORT:$PORT -e SNAKE_CLASS="$SNAKE_CLASS" "$IMAGE_NAME")

echo "Container ID: $CONTAINER_ID"

# Wait for server to start
echo ""
echo "Waiting for server to start..."
sleep 5

# Test root endpoint
echo ""
echo "Testing GET /..."
ROOT_RESPONSE=$(curl -s http://localhost:$PORT/)
echo "$ROOT_RESPONSE" | jq .

# Verify required fields
if echo "$ROOT_RESPONSE" | jq -e '.name and .color and .head and .tail' > /dev/null; then
    echo "✅ Root endpoint OK"
else
    echo "❌ Root endpoint missing required fields"
    docker logs "$CONTAINER_ID"
    docker stop "$CONTAINER_ID" > /dev/null
    docker rm "$CONTAINER_ID" > /dev/null
    exit 1
fi

# Test move endpoint
echo ""
echo "Testing POST /move..."
GAME_STATE='{
  "game": {
    "id": "test-game",
    "ruleset": {"name": "standard"},
    "timeout": 500
  },
  "turn": 1,
  "board": {
    "height": 11,
    "width": 11,
    "food": [{"x": 5, "y": 5}],
    "hazards": [],
    "snakes": [
      {
        "id": "test-snake",
        "name": "Test Snake",
        "health": 100,
        "body": [{"x": 1, "y": 1}, {"x": 1, "y": 0}],
        "head": {"x": 1, "y": 1},
        "length": 2,
        "shout": ""
      }
    ]
  },
  "you": {
    "id": "test-snake",
    "name": "Test Snake",
    "health": 100,
    "body": [{"x": 1, "y": 1}, {"x": 1, "y": 0}],
    "head": {"x": 1, "y": 1},
    "length": 2,
    "shout": ""
  }
}'

MOVE_RESPONSE=$(curl -s -X POST http://localhost:$PORT/move \
    -H "Content-Type: application/json" \
    -d "$GAME_STATE")

echo "$MOVE_RESPONSE" | jq .

# Verify move is valid
MOVE=$(echo "$MOVE_RESPONSE" | jq -r '.move')
if [[ "$MOVE" =~ ^(up|down|left|right)$ ]]; then
    echo "✅ Move endpoint OK (returned: $MOVE)"
else
    echo "❌ Move endpoint returned invalid move: $MOVE"
    docker logs "$CONTAINER_ID"
    docker stop "$CONTAINER_ID" > /dev/null
    docker rm "$CONTAINER_ID" > /dev/null
    exit 1
fi

# Test start endpoint
echo ""
echo "Testing POST /start..."
START_RESPONSE=$(curl -s -X POST http://localhost:$PORT/start \
    -H "Content-Type: application/json" \
    -d "$GAME_STATE")

echo "$START_RESPONSE" | jq .

# Test end endpoint
echo ""
echo "Testing POST /end..."
END_RESPONSE=$(curl -s -X POST http://localhost:$PORT/end \
    -H "Content-Type: application/json" \
    -d "$GAME_STATE")

echo "$END_RESPONSE" | jq .

# Show container logs
echo ""
echo "Container logs:"
echo "================================="
docker logs "$CONTAINER_ID"
echo "================================="

# Clean up
echo ""
echo "Stopping and removing container..."
docker stop "$CONTAINER_ID" > /dev/null
docker rm "$CONTAINER_ID" > /dev/null

echo ""
echo "✅ All tests passed!"
echo ""
echo "You can now deploy this image to:"
echo "  - Fly.io: fly deploy --build-arg SNAKE_CLASS=$SNAKE_CLASS"
echo "  - Railway: Push to GitHub (uses railway.json)"
echo "  - Render: Push to GitHub (uses render.yaml)"

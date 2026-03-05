#!/bin/bash
# Test script for Docker deployment
# Usage: ./test-docker.sh [snake-class]
# Example: ./test-docker.sh cautious
set -e

SNAKE="${1:-random}"
PORT=8080
IMAGE_NAME="cl-battlesnake-test"

echo "================================="
echo "Testing Docker deployment"
echo "Snake: $SNAKE"
echo "================================="

echo ""
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" --build-arg SNAKE_CLASS="$SNAKE" .

echo ""
echo "Starting container..."
CONTAINER_ID=$(docker run -d -p $PORT:$PORT -e SNAKE_CLASS="$SNAKE" "$IMAGE_NAME")
echo "Container ID: $CONTAINER_ID"

echo ""
echo "Waiting for server to start..."
for i in $(seq 1 20); do
    if ! docker ps -q --no-trunc | grep -q "$CONTAINER_ID"; then
        echo "❌ Container exited early"
        docker logs "$CONTAINER_ID"
        exit 1
    fi
    if curl -sf http://localhost:$PORT/$SNAKE/ > /dev/null 2>&1; then
        echo "Server ready after ${i}s"
        break
    fi
    if [ "$i" -eq 20 ]; then
        echo "❌ Server failed to start within 20s"
        docker logs "$CONTAINER_ID"
        docker stop "$CONTAINER_ID" > /dev/null
        docker rm "$CONTAINER_ID" > /dev/null
        exit 1
    fi
    sleep 1
done

BASE="http://localhost:$PORT/$SNAKE"
GAME_STATE='{
  "game": {"id":"test-game","ruleset":{"name":"standard"},"timeout":500},
  "turn": 1,
  "board": {
    "height":11,"width":11,
    "food":[{"x":5,"y":5}],
    "hazards":[],
    "snakes":[{"id":"test-snake","name":"Test Snake","health":100,
               "body":[{"x":1,"y":1},{"x":1,"y":0}],
               "head":{"x":1,"y":1},"length":2,"shout":""}]
  },
  "you": {"id":"test-snake","name":"Test Snake","health":100,
          "body":[{"x":1,"y":1},{"x":1,"y":0}],
          "head":{"x":1,"y":1},"length":2,"shout":""}
}'

cleanup() {
    docker stop "$CONTAINER_ID" > /dev/null
    docker rm "$CONTAINER_ID" > /dev/null
}

echo ""
echo "Testing GET /$SNAKE/..."
ROOT_RESPONSE=$(curl -sf --max-time 10 "$BASE/")
echo "$ROOT_RESPONSE" | jq .

if echo "$ROOT_RESPONSE" | jq -e '.name and .color and .head and .tail' > /dev/null; then
    echo "✅ Root endpoint OK"
else
    echo "⚠️  Root endpoint missing required fields"
fi

echo ""
echo "Testing POST /$SNAKE/move..."
MOVE_RESPONSE=$(curl -sf --max-time 10 -X POST "$BASE/move" \
    -H "Content-Type: application/json" -d "$GAME_STATE")
echo "$MOVE_RESPONSE" | jq .

MOVE=$(echo "$MOVE_RESPONSE" | jq -r '.move')
if [[ "$MOVE" =~ ^(up|down|left|right)$ ]]; then
    echo "✅ Move endpoint OK (returned: $MOVE)"
else
    echo "❌ Move endpoint returned invalid move: $MOVE"
    docker logs "$CONTAINER_ID"
    cleanup
    exit 1
fi

echo ""
echo "Testing POST /$SNAKE/start..."
curl -sf --max-time 10 -X POST "$BASE/start" \
    -H "Content-Type: application/json" -d "$GAME_STATE" | jq .
echo "✅ Start endpoint OK"

echo ""
echo "Testing POST /$SNAKE/end..."
curl -sf --max-time 10 -X POST "$BASE/end" \
    -H "Content-Type: application/json" -d "$GAME_STATE" | jq .
echo "✅ End endpoint OK"

echo ""
echo "Container logs:"
echo "================================="
docker logs "$CONTAINER_ID"
echo "================================="

cleanup

echo ""
echo "✅ All tests passed!"
echo ""
echo "You can now deploy this image to:"
echo "  - Fly.io: fly deploy --build-arg SNAKE_CLASS=$SNAKE"
echo "  - Railway: Push to GitHub (uses railway.json)"
echo "  - Render: Push to GitHub (uses render.yaml)"

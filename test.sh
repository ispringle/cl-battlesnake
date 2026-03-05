#!/bin/bash
# Test script for local server at localhost:8080
set -e

PORT=8080
SNAKE="${1:-random}"

echo "================================="
echo "Testing server at localhost:$PORT/$SNAKE"
echo "================================="

BASE="http://localhost:$PORT/$SNAKE"

# Test root endpoint
echo ""
echo "Testing GET /$SNAKE..."
ROOT_RESPONSE=$(curl -sf --max-time 10 "$BASE/")
echo "$ROOT_RESPONSE" | jq .

if echo "$ROOT_RESPONSE" | jq -e '.name and .color and .head and .tail' > /dev/null; then
    echo "✅ Root endpoint OK"
else
    echo "⚠️  Root endpoint missing required fields"
fi

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
echo "✅ All tests passed!"

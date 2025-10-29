#!/bin/bash
set -e

echo "Testing backend container..."

# Test health endpoint
echo "Testing /health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:5000/health)
if ! echo "$HEALTH_RESPONSE" | grep -q '"status".*"healthy"'; then
  echo "❌ Health check failed!"
  echo "Response: $HEALTH_RESPONSE"
  exit 1
fi
echo "✅ Health check passed"

# Test message endpoint returns 200
echo "Testing /api/message endpoint..."
MESSAGE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/message)
if [ "$MESSAGE_STATUS" != "200" ]; then
  echo "❌ Message endpoint returned status $MESSAGE_STATUS"
  exit 1
fi
echo "✅ Message endpoint returned 200"

# Test message endpoint returns valid JSON with message field
echo "Testing message endpoint response structure..."
MESSAGE_RESPONSE=$(curl -s http://localhost:5000/api/message)
if ! echo "$MESSAGE_RESPONSE" | grep -q '"message"'; then
  echo "❌ Message response missing 'message' field!"
  echo "Response: $MESSAGE_RESPONSE"
  exit 1
fi
echo "✅ Message response has correct structure"

# Verify message is one of the expected messages
echo "Testing message content..."
EXPECTED_MESSAGES=(
  "Your pipeline is green"
  "Your tests are well-written and stable"
  "Your friends and family understand what you do"
  "Your friends and family appreciate your humerous work stories"
  "That joke you told in your meeting was funny. If your coworkers weren't on mute, you would have heard them laughing"
)

MESSAGE=$(echo "$MESSAGE_RESPONSE" | tr -d '\n' | sed 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
FOUND=0
for EXPECTED in "${EXPECTED_MESSAGES[@]}"; do
  if [ "$MESSAGE" = "$EXPECTED" ]; then
    FOUND=1
    break
  fi
done

if [ $FOUND -eq 0 ]; then
  echo "❌ Message not in expected list: $MESSAGE"
  exit 1
fi
echo "✅ Message is valid: $MESSAGE"

echo ""
echo "🎉 All backend container tests passed!"

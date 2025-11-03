#!/bin/bash
set -e

# Use PORT environment variable or default to 3001 to avoid conflicts with k8s
PORT=${PORT:-3001}

echo "Testing frontend container on port $PORT..."

# Test that frontend returns 200
echo "Testing frontend accessibility..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT)
if [ "$FRONTEND_STATUS" != "200" ]; then
  echo "❌ Frontend returned status $FRONTEND_STATUS"
  exit 1
fi
echo "✅ Frontend is accessible"

# Test that frontend HTML contains the app title
echo "Testing frontend content..."
FRONTEND_RESPONSE=$(curl -s http://localhost:$PORT)
if ! echo "$FRONTEND_RESPONSE" | grep -q "cuddly-disco.ai"; then
  echo "❌ Frontend doesn't contain expected title!"
  exit 1
fi
echo "✅ Frontend contains app title"

# Test that frontend HTML contains Next.js production bundle
echo "Testing Next.js bundle is loaded..."
if ! echo "$FRONTEND_RESPONSE" | grep -q '_next/static'; then
  echo "❌ Frontend doesn't load Next.js bundle!"
  exit 1
fi
echo "✅ Next.js bundle is loaded"

# Verify server-side rendering works
echo "Testing server-side rendering..."
if ! echo "$FRONTEND_RESPONSE" | grep -q 'For all the SREs out there'; then
  echo "❌ Frontend is not server-rendered!"
  exit 1
fi
echo "✅ Server-side rendering works"

# Test that frontend handles backend unavailability gracefully
echo "Testing backend error handling..."
if echo "$FRONTEND_RESPONSE" | grep -q 'Unable to connect to backend service'; then
  echo "✅ Frontend gracefully handles backend unavailability"
else
  # If backend is available, verify a valid message is shown instead
  if echo "$FRONTEND_RESPONSE" | grep -qE '(Your pipeline is green|Your tests are well-written|Your friends and family)'; then
    echo "✅ Frontend displays backend message (backend is available)"
  else
    echo "❌ Frontend doesn't show expected message or error!"
    exit 1
  fi
fi

# Test Next.js API health endpoint
echo "Testing Next.js health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/api/health)
if [ "$HEALTH_STATUS" != "200" ]; then
  echo "❌ Health endpoint returned status $HEALTH_STATUS"
  exit 1
fi
echo "✅ Health endpoint is accessible"

echo ""
echo "🎉 All frontend container tests passed!"

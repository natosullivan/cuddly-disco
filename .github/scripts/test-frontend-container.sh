#!/bin/bash
set -e

echo "Testing frontend container..."

# Test that frontend returns 200
echo "Testing frontend accessibility..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$FRONTEND_STATUS" != "200" ]; then
  echo "❌ Frontend returned status $FRONTEND_STATUS"
  exit 1
fi
echo "✅ Frontend is accessible"

# Test that frontend HTML contains the app title
echo "Testing frontend content..."
FRONTEND_RESPONSE=$(curl -s http://localhost:3000)
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

# Test Next.js API health endpoint
echo "Testing Next.js health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)
if [ "$HEALTH_STATUS" != "200" ]; then
  echo "❌ Health endpoint returned status $HEALTH_STATUS"
  exit 1
fi
echo "✅ Health endpoint is accessible"

echo ""
echo "🎉 All frontend container tests passed!"

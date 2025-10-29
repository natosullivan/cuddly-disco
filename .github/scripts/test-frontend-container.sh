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

# Test that frontend HTML contains the production bundle
echo "Testing production bundle is loaded..."
if ! echo "$FRONTEND_RESPONSE" | grep -q '/assets/index-.*\.js'; then
  echo "❌ Frontend doesn't load production bundle!"
  exit 1
fi
echo "✅ Production bundle is loaded"

# Verify the app root div exists
echo "Testing React app structure..." #Test
if ! echo "$FRONTEND_RESPONSE" | grep -q 'id="root"'; then
  echo "❌ Frontend missing React root div!"
  exit 1
fi
echo "✅ React app structure is correct"

# Test nginx health endpoint
echo "Testing nginx health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
if [ "$HEALTH_STATUS" != "200" ]; then
  echo "❌ Health endpoint returned status $HEALTH_STATUS"
  exit 1
fi
echo "✅ Health endpoint is accessible"

echo ""
echo "🎉 All frontend container tests passed!"

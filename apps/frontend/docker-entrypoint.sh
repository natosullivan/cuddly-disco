#!/bin/sh
set -e

# Generate config.js from environment variables
# This allows runtime configuration in Kubernetes
cat /usr/share/nginx/html/config.js.template | \
  sed "s|\${VITE_LOCATION}|${VITE_LOCATION:-Production}|g" | \
  sed "s|\${VITE_BACKEND_URL}|${VITE_BACKEND_URL:-http://localhost:5000}|g" \
  > /usr/share/nginx/html/config.js

echo "Generated config.js with:"
echo "  VITE_LOCATION=${VITE_LOCATION:-Production}"
echo "  VITE_BACKEND_URL=${VITE_BACKEND_URL:-http://localhost:5000}"

# Start nginx
exec nginx -g 'daemon off;'

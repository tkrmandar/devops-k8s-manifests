#!/bin/bash

# Blue Green Switch Script
# Usage: ./blue-green-switch.sh [blue|green]

set -e

TARGET=$1
NAMESPACE="prod"
INGRESS_FILE="prod/ingress.yaml"

# Validate input
if [ -z "$TARGET" ]; then
  echo "❌ Error: Please specify target slot"
  echo "Usage: ./prod/blue-green-switch.sh [blue|green]"
  exit 1
fi

if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
  echo "❌ Error: Target must be 'blue' or 'green'"
  exit 1
fi

# Find current active slot
CURRENT=$(kubectl get ingress task-manager-api-ingress \
  -n $NAMESPACE \
  -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' \
  2>/dev/null || echo "unknown")

echo "================================================"
echo "🔄 Blue Green Switch"
echo "================================================"
echo "Current active slot : $CURRENT"
echo "Switching to        : $TARGET"
echo "Namespace           : $NAMESPACE"
echo "================================================"

# Confirm switch
read -p "Are you sure you want to switch to $TARGET? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Switch cancelled"
  exit 0
fi

# Verify target pods are healthy before switching
echo ""
echo "🔍 Checking $TARGET pods health..."
READY=$(kubectl get deployment task-manager-api-$TARGET \
  -n $NAMESPACE \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

DESIRED=$(kubectl get deployment task-manager-api-$TARGET \
  -n $NAMESPACE \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

echo "$TARGET pods: $READY/$DESIRED ready"

if [ "$READY" != "$DESIRED" ] || [ "$READY" == "0" ]; then
  echo "❌ Error: $TARGET pods are not fully ready!"
  echo "Please ensure $TARGET deployment is healthy before switching"
  exit 1
fi

echo "✅ $TARGET pods are healthy"

# Update ingress to point to target slot
echo ""
echo "🔄 Updating ingress to point to $TARGET..."

sed -i "s|task-manager-api-blue-svc|task-manager-api-TARGET-svc|g" $INGRESS_FILE
sed -i "s|task-manager-api-green-svc|task-manager-api-TARGET-svc|g" $INGRESS_FILE
sed -i "s|task-manager-api-TARGET-svc|task-manager-api-$TARGET-svc|g" $INGRESS_FILE

# Apply updated ingress
kubectl apply -f $INGRESS_FILE

echo ""
echo "✅ Traffic switched to $TARGET successfully!"
echo ""

# Verify switch
echo "🔍 Verifying ingress..."
kubectl get ingress task-manager-api-ingress -n $NAMESPACE

echo ""
echo "================================================"
echo "✅ Blue Green switch complete!"
echo "   Active slot : $TARGET"
echo "   Previous    : $CURRENT"
echo ""
echo "💡 To rollback run:"
if [ "$TARGET" == "green" ]; then
  echo "   ./prod/blue-green-switch.sh blue"
else
  echo "   ./prod/blue-green-switch.sh green"
fi
echo "================================================"

#!/bin/bash

echo "🔍 CHECKING IF RAILWAY HAS THE LATEST CODE"
echo ""
echo "Latest commit:"
git log --oneline -1
echo ""
echo "✅ If Railway shows this commit, the code is deployed"
echo "❌ If not, Railway is still building"
echo ""
echo "🔥 GO TO: https://railway.app"
echo "1. Click your backend service"
echo "2. Click 'Deployments' tab"
echo "3. Look for commit: $(git log --oneline -1 | cut -d' ' -f1)"
echo "4. Check if it says 'Active'"
echo ""
echo "📋 THEN CHECK LOGS for:"
echo "   🔧 Scheduler worker initialized and listening for jobs..."
echo "   ⏰ Scan alarms processed: X"


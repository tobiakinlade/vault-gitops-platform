#!/bin/bash

# Script to generate correct go.sum file for the backend
# Run this from the tax-calculator-demo directory

echo "🔧 Generating correct go.sum file..."
echo ""

cd backend

# Remove old go.sum if it exists
if [ -f go.sum ]; then
    echo "📝 Removing old go.sum..."
    rm go.sum
fi

# Download dependencies and generate go.sum
echo "📦 Downloading dependencies..."
go mod download

# Tidy up go.mod and go.sum
echo "🧹 Tidying modules..."
go mod tidy

# Verify everything
echo "✅ Verifying modules..."
go mod verify

echo ""
echo "✅ Done! go.sum file generated successfully."
echo ""
echo "You can now build with Docker:"
echo "  cd .."
echo "  docker-compose build backend"
echo ""

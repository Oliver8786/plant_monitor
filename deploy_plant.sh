#!/bin/bash

# Step 1: Build Flutter web
echo "Building Flutter web..."
flutter build web

# Step 2: Add all changes
echo "Adding changes..."
git add .

# Step 3: Ask for commit message
read -p "Enter commit message: " commit_message

# Step 4: Commit with the message
git commit -m "$commit_message"

# Step 5: Push to main branch
echo "Pushing to main..."
git push origin main

echo "Deployment complete!"

#!/bin/bash

set -euo pipefail

# Configuration
SOURCE_GITLAB="https://gitlab.com"
DEST_GITLAB="https://gitlab.example.com"

SOURCE_REGISTRY="registry.gitlab.com"
DEST_REGISTRY="gitlab.example.com"

SOURCE_GROUP="source-group-name"  # e.g., mygroup
DEST_GROUP="destination-group-name"

SOURCE_TOKEN="your-source-private-token"
DEST_TOKEN="your-destination-private-token"

# API headers
SOURCE_HEADER="PRIVATE-TOKEN: $SOURCE_TOKEN"
DEST_HEADER="PRIVATE-TOKEN: $DEST_TOKEN"

# Docker login
echo "$SOURCE_TOKEN" | docker login "$SOURCE_REGISTRY" -u oauth2 --password-stdin
echo "$DEST_TOKEN"   | docker login "$DEST_REGISTRY" -u oauth2 --password-stdin

# Get all projects under the source group
echo "Fetching projects from group: $SOURCE_GROUP"
SOURCE_GROUP_ID=$(curl -s --header "$SOURCE_HEADER" "$SOURCE_GITLAB/api/v4/groups?search=$SOURCE_GROUP" | jq ".[0].id")

PROJECTS=$(curl -s --header "$SOURCE_HEADER" "$SOURCE_GITLAB/api/v4/groups/$SOURCE_GROUP_ID/projects?per_page=100" | jq -r '.[].id')

for PROJECT_ID in $PROJECTS; do
  PROJECT_PATH=$(curl -s --header "$SOURCE_HEADER" "$SOURCE_GITLAB/api/v4/projects/$PROJECT_ID" | jq -r '.path_with_namespace')
  echo "Found project: $PROJECT_PATH"

  # Get container registry repositories
  REPOS=$(curl -s --header "$SOURCE_HEADER" "$SOURCE_GITLAB/api/v4/projects/$PROJECT_ID/registry/repositories" | jq -c '.[]')

  if [ "$REPOS" == "" ]; then
    echo "No registry repositories found in $PROJECT_PATH"
    continue
  fi

  echo "$REPOS" | while read -r repo; do
    REPO_ID=$(echo "$repo" | jq -r '.id')
    REPO_PATH=$(echo "$repo" | jq -r '.path')

    # List all tags
    TAGS=$(curl -s --header "$SOURCE_HEADER" "$SOURCE_GITLAB/api/v4/projects/$PROJECT_ID/registry/repositories/$REPO_ID/tags?per_page=100" | jq -r '.[].name')

    for TAG in $TAGS; do
      SRC_IMAGE="$SOURCE_REGISTRY/$REPO_PATH:$TAG"
      DEST_IMAGE="$DEST_REGISTRY/$DEST_GROUP/$REPO_PATH:$TAG"

      echo "Copying $SRC_IMAGE → $DEST_IMAGE"

      docker pull "$SRC_IMAGE"
      docker tag "$SRC_IMAGE" "$DEST_IMAGE"
      docker push "$DEST_IMAGE"

      echo "✔ Successfully copied: $SRC_IMAGE to $DEST_IMAGE"
    done
  done
done

echo "✅ All images transferred."
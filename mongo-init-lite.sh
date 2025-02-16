#!/bin/bash
# This script will import a pre-filtered MongoDB archive into MongoDB.

set -e  # Exit immediately if a command exits with a non-zero status.

ARCHIVE_PATH="../db/opendfoodfact_skrinked.gz"

# Check if the provided archive path exists
if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "Error: File '$ARCHIVE_PATH' not found!"
    exit 1
fi

# Wait for MongoDB to be ready
echo "=== Waiting for MongoDB to be ready... ==="
until mongosh --host localhost --eval "print(\"waited for connection\")"
do
    sleep 2
    echo "Waiting for MongoDB to be ready..."
done

# Import the pre-filtered data
echo "Importing data into MongoDB..."
mongorestore -vvvvv --host localhost \
    --gzip \
    --archive="$ARCHIVE_PATH" \
    --nsFrom=off.products \
    --nsTo=openfoodfact.products \
    --drop

echo "MongoDB import complete!"
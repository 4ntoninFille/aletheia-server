#!/bin/bash
# This script will download and filter the OpenFoodFacts MongoDB database.
# Warning: The database exceeds 60GB, so ensure you run this on a local machine or a large server.
# For a lightweight alternative, use `mongofb-init-lite.sh` to download an archived database from GitHub.

set -e  # Exit immediately if a command exits with a non-zero status.

FORCE_DOWNLOAD=false

# Check for -f argument to force download
while getopts "f" opt; do
  case $opt in
    f)
      FORCE_DOWNLOAD=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Wait for MongoDB to be ready
echo "=== Waiting for MongoDB to be ready... ==="
until mongosh --host localhost  --eval "print(\"waited for connection\")"
do
    sleep 2
    echo "Waiting for MongoDB to be ready..."
done

# Download the OpenFoodFacts MongoDB dump if it doesn't already exist or if force download is enabled
if [ ! -f /tmp/openfoodfacts-mongodbdump.gz ] || [ "$FORCE_DOWNLOAD" = true ]; then
    echo "Downloading OpenFoodFacts MongoDB dump..."
    wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.gz -O /tmp/openfoodfacts-mongodbdump.gz
else
    echo "OpenFoodFacts MongoDB dump already exists. Skipping download."
fi

# First, import the data
echo "Importing data into MongoDB..."
mongorestore -vvvvv --host localhost \
    --gzip \
    --archive="/tmp/openfoodfacts-mongodbdump.gz" \
    --nsFrom=off.products \
    --nsTo=openfoodfact.products \
    --drop

# Then, filter and transform the data
echo "Filtering and transforming data..."
# shellcheck disable=SC2016
mongosh --host localhost --eval '
    print(db.getName());
    // First, let us see what we have
    print("Initial count:", db.products.countDocuments());
     
    // Count documents matching our criteria
    const matchingDocs = db.products.countDocuments({
        code: { $exists: true },
        product_name: { $exists: true },
        nutriscore_grade: { $exists: true },
        ecoscore_grade: { $exists: true }
    });
    print("\nDocuments matching all required fields:", matchingDocs);
    
    // Now perform the filtering
    db.products.aggregate([
        {
            $match: {
                code: { $exists: true },
                product_name: { $exists: true },
                nutriscore_grade: { $exists: true },
                ecoscore_grade: { $exists: true }
            }
        },
        {
            $project: {
                _id: 0,
                code: 1,
                product_name: 1,
                nutriscore_grade: 1,
                ecoscore_grade: 1
            }
        },
        {
            $match: {
                code: { $type: "string" },
                product_name: { $type: "string" },
                nutriscore_grade: { $type: "string" },
                ecoscore_grade: { $type: "string" }
            }
        },
        {
            $out: "products_filtered"
        }
    ], { allowDiskUse: true });
    
    // Check results
    print("\nFiltered collection count:", db.products_filtered.countDocuments());
    
    // Replace original collection
    db.products.drop();
    db.products_filtered.renameCollection("products");
    
    // Create index
    db.products.createIndex({ "code": 1 });
    
    // Show final result
    print("\nFinal collection count:", db.products.countDocuments());
    print("\nFinal sample document:");
    print(JSON.stringify(db.products.findOne(), null, 2));
' openfoodfact

echo "MongoDB import and filtering complete!"

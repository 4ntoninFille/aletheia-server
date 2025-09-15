#!/bin/bash
# This script will download and filter the OpenFoodFacts MongoDB database.
# Warning: The database exceeds 60GB, so ensure you run this on a local machine or a large server.

set -e  # Exit immediately if a command exits with a non-zero status.

FORCE_DOWNLOAD=false
DB_NAME="openfoodfacts"  # Fixed database name

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
until mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1
do
    sleep 2
    echo "Waiting for MongoDB to be ready..."
done
echo "MongoDB is ready!"

# Download the OpenFoodFacts MongoDB dump if it doesn't already exist or if force download is enabled
if [ ! -f /tmp/openfoodfacts-mongodbdump.gz ] || [ "$FORCE_DOWNLOAD" = true ]; then
    echo "Downloading OpenFoodFacts MongoDB dump..."
    wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.gz -O /tmp/openfoodfacts-mongodbdump.gz
else
    echo "OpenFoodFacts MongoDB dump already exists. Skipping download."
fi

# Check file size before importing
echo "Checking downloaded file..."
ls -lh /tmp/openfoodfacts-mongodbdump.gz

# First, import the data
echo "Importing data into MongoDB..."
mongorestore --host localhost \
    --gzip \
    --archive="/tmp/openfoodfacts-mongodbdump.gz" \
    --nsFrom="off.products" \
    --nsTo="${DB_NAME}.products" \
    --drop

# Create check_import.js file
cat > /tmp/check_import.js << 'EOF'
db = db.getSiblingDB(process.env.DB_NAME || 'openfoodfacts');
print('Total documents imported:', db.products.countDocuments());
print('Database size:', JSON.stringify(db.stats().dataSize));
EOF

# Check import success
echo "Checking import results..."
DB_NAME="$DB_NAME" mongosh --quiet /tmp/check_import.js

# Create the main filtering script with flexible requirements
cat > /tmp/filter_data.js << 'EOF'
db = db.getSiblingDB(process.env.DB_NAME || 'openfoodfacts');

print('Database:', db.getName());
const initialCount = db.products.countDocuments();
print('=== BEFORE FILTERING ===');
print('Initial count:', initialCount);

// Let's first check what fields actually exist in a sample
print('\nSample document structure:');
const sample = db.products.findOne();
if (sample) {
    print('Available fields in sample:', Object.keys(sample));
    print('Sample code:', sample.code);
    print('Sample product_name:', sample.product_name);
    print('Sample nutriscore_grade:', sample.nutriscore_grade);
    print('Sample ecoscore_grade:', sample.ecoscore_grade);
}

// FLEXIBLE FILTERING: Only require nutriscore_grade as mandatory
// Other fields are optional but will be included if they exist
const mandatoryFields = ['nutriscore_grade']; // Only nutriscore_grade is required
const optionalFields = ['code', 'product_name', 'ecoscore_grade']; // These are nice to have

// Build match condition - only nutriscore_grade must exist and be valid
let matchCondition = {};
mandatoryFields.forEach(field => {
    matchCondition[field] = { $exists: true, $ne: null, $ne: '' };
});

const matchingDocs = db.products.countDocuments(matchCondition);
print('\n=== FIELD ANALYSIS ===');
print('Documents with MANDATORY fields (nutriscore_grade):', matchingDocs);
print('Percentage of products that will survive filtering:', ((matchingDocs / initialCount) * 100).toFixed(2) + '%');

// Check individual field availability for all fields
print('\nField availability analysis:');
const allFields = [...mandatoryFields, ...optionalFields];
allFields.forEach(field => {
    const existsCount = db.products.countDocuments({ [field]: { $exists: true } });
    const validCount = db.products.countDocuments({ [field]: { $exists: true, $ne: null, $ne: '' } });
    const status = mandatoryFields.includes(field) ? '[REQUIRED]' : '[OPTIONAL]';
    print(field + ' ' + status + ' - exists: ' + existsCount + ', valid: ' + validCount + ' (' + ((validCount/initialCount)*100).toFixed(1) + '%)');
});

if (matchingDocs === 0) {
    print('\n=== ERROR: NO MATCHING DOCUMENTS ===');
    print('No documents have valid nutriscore_grade!');
} else {
    print('\nStarting flexible aggregation pipeline...');
    
    // Perform the filtering with flexible requirements
    try {
        db.products.aggregate([
            {
                // Only filter by mandatory fields (nutriscore_grade)
                $match: matchCondition
            },
            {
                // Project all desired fields, handling nested ecoscore_grade
                $project: {
                    _id: 0,
                    code: { $ifNull: ['$code', ''] },
                    product_name: { $ifNull: ['$product_name', ''] },
                    nutriscore_grade: '$nutriscore_grade', // This is guaranteed to exist
                    ecoscore_grade: { 
                        $ifNull: [
                            '$ecoscore_grade',  // Try root level first
                            {
                                $ifNull: [
                                    '$ecoscore_data.grade',  // Then try nested
                                    {
                                        $ifNull: [
                                            { $arrayElemAt: ['$ecoscore_tags', 0] },  // Then try first element of ecoscore_tags array
                                            ''
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                }
            },
            {
                // Final validation: only ensure nutriscore_grade is a valid string
                $match: {
                    nutriscore_grade: { $type: 'string', $ne: '' }
                }
            },
            {
                $out: 'products_filtered'
            }
        ], { 
            allowDiskUse: true,
            maxTimeMS: 0  // No timeout
        });
        
        const filteredCount = db.products_filtered.countDocuments();
        print('\n=== AFTER FILTERING ===');
        print('Filtered collection count:', filteredCount);
        print('Products retained:', filteredCount + ' out of ' + initialCount);
        print('Retention rate:', ((filteredCount / initialCount) * 100).toFixed(2) + '%');
        
        if (filteredCount > 0) {
            // Analyze the quality of filtered data
            print('\n=== DATA QUALITY ANALYSIS ===');
            const withCode = db.products_filtered.countDocuments({ code: { $ne: '' } });
            const withProductName = db.products_filtered.countDocuments({ product_name: { $ne: '' } });
            const withEcoscore = db.products_filtered.countDocuments({ ecoscore_grade: { $ne: '' } });
            const withNutriscore = db.products_filtered.countDocuments({ nutriscore_grade: { $ne: '' } });
            
            print('Products with code:', withCode, '(' + ((withCode/filteredCount)*100).toFixed(1) + '%)');
            print('Products with product_name:', withProductName, '(' + ((withProductName/filteredCount)*100).toFixed(1) + '%)');
            print('Products with ecoscore_grade:', withEcoscore, '(' + ((withEcoscore/filteredCount)*100).toFixed(1) + '%)');
            print('Products with nutriscore_grade:', withNutriscore, '(' + ((withNutriscore/filteredCount)*100).toFixed(1) + '%)');
            
            // Show sample of filtered data
            print('\n=== SAMPLE DATA ===');
            const samples = db.products_filtered.find().limit(3).toArray();
            samples.forEach((doc, index) => {
                print('Sample ' + (index + 1) + ':');
                printjson(doc);
            });
            
            // Size comparison before replacement
            const originalSize = db.products.stats().storageSize;
            const filteredSize = db.products_filtered.stats().storageSize;
            
            print('\n=== SIZE COMPARISON ===');
            print('Original collection storage size:', (originalSize / (1024*1024*1024)).toFixed(2), 'GB');
            print('Filtered collection storage size:', (filteredSize / (1024*1024*1024)).toFixed(2), 'GB');
            print('Size reduction:', ((originalSize - filteredSize) / originalSize * 100).toFixed(1) + '%');
            
            // Replace original collection
            db.products.drop();
            db.products_filtered.renameCollection('products');
            
            // Create useful indexes
            db.products.createIndex({ 'nutriscore_grade': 1 });
            db.products.createIndex({ 'code': 1 }, { sparse: true }); // Sparse index for code (since it might be empty)
            
            const finalCount = db.products.countDocuments();
            print('\n=== FINAL RESULTS ===');
            print('✅ Processing complete!');
            print('Final collection count:', finalCount);
            print('Documents processed successfully:', (finalCount === filteredCount ? 'YES' : 'NO'));
            
            if (finalCount !== filteredCount) {
                print('⚠️  WARNING: Final count differs from filtered count!');
            }
            
        } else {
            print('\n❌ ERROR: No documents survived the filtering process!');
            print('This suggests no products have valid nutriscore_grade values.');
        }
        
    } catch (e) {
        print('ERROR during aggregation:', e.message);
        print('Stack trace:', e.stack);
    }
}
EOF

# Then, filter and transform the data
echo "Filtering and transforming data with flexible requirements..."
DB_NAME="$DB_NAME" mongosh /tmp/filter_data.js

echo "MongoDB import and filtering complete!"

# Create final stats script
cat > /tmp/final_stats.js << 'EOF'
db = db.getSiblingDB(process.env.DB_NAME || 'openfoodfacts');
const finalCount = db.products.countDocuments();
const stats = db.products.stats();

print('=== FINAL SUMMARY ===');
print('Final document count:', finalCount);
print('Collection size:', (stats.size / (1024*1024)).toFixed(2), 'MB');
print('Storage size:', (stats.storageSize / (1024*1024)).toFixed(2), 'MB');
print('Average document size:', stats.avgObjSize, 'bytes');
print('Index size:', (db.products.totalIndexSize() / (1024*1024)).toFixed(2), 'MB');

// Show database-level stats
const dbStats = db.stats();
print('Total database size:', (dbStats.dataSize / (1024*1024*1024)).toFixed(2), 'GB');
print('Total storage size:', (dbStats.storageSize / (1024*1024*1024)).toFixed(2), 'GB');

// Show final data quality
print('\n=== FINAL DATA QUALITY ===');
const withCode = db.products.countDocuments({ code: { $ne: '' } });
const withProductName = db.products.countDocuments({ product_name: { $ne: '' } });
const withEcoscore = db.products.countDocuments({ ecoscore_grade: { $ne: '' } });
const withNutriscore = db.products.countDocuments({ nutriscore_grade: { $ne: '' } });

print('Products with valid code:', withCode, '(' + ((withCode/finalCount)*100).toFixed(1) + '%)');
print('Products with valid product_name:', withProductName, '(' + ((withProductName/finalCount)*100).toFixed(1) + '%)');
print('Products with valid ecoscore_grade:', withEcoscore, '(' + ((withEcoscore/finalCount)*100).toFixed(1) + '%)');
print('Products with valid nutriscore_grade:', withNutriscore, '(' + ((withNutriscore/finalCount)*100).toFixed(1) + '%)');
EOF

# Show final statistics
echo "=== FINAL DATABASE STATISTICS ==="
DB_NAME="$DB_NAME" mongosh --quiet /tmp/final_stats.js

# Clean up temporary files
rm -f /tmp/check_import.js /tmp/filter_data.js /tmp/final_stats.js
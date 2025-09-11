# Aletheia-server
This is the backend server of Aletheia, hosting the database.

## Database Initialization

### Prerequisites
- MongoDB installed via Homebrew: `brew install mongodb-community`
- ~70GB free disk space for full OpenFoodFacts dataset

### Quick Start
```bash
# Start MongoDB
brew services start mongodb-community

# Run database initialization
./mongofb-init.sh

# Or force re-download
./mongofb-init.sh -f
```

### What happens during init:
1. Downloads 60GB OpenFoodFacts dump
2. Imports all products (~3M documents)
3. Filters to products with required fields (code, name, nutriscore, ecoscore)
4. Reduces database to ~200MB with only needed columns

## Good to Know

**Database Size**: Expect 200MB final size from 60GB source
**Processing Time**: 1-3 hours depending on machine
**Retention Rate**: ~10-30% of original products survive filtering
**Required Fields**: Products must have code, name, nutriscore_grade, ecoscore_grade

**Check Status**:
```bash
mongosh --eval "use openfoodfacts; db.products.countDocuments()"
```

**Clean Up**: Remove `/tmp/openfoodfacts-mongodbdump.gz` after successful init
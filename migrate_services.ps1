# Firebase to Supabase Service Migration Script
# Migrates all 8 remaining service files from Firestore to Supabase

Write-Host "Starting Firebase to Supabase Service Migration..." -ForegroundColor Cyan
Write-Host ""

# Define service files to migrate
$services = @(
    "lib\core\services\topup_service.dart",
    "lib\core\services\order_service.dart",
    "lib\core\services\weekly_menu_analytics_service.dart",
    "lib\core\services\menu_service.dart",
    "lib\core\services\parent_service.dart",
    "lib\core\services\student_service.dart",
    "lib\core\services\weekly_menu_service.dart"
)

$totalFiles = $services.Count
$currentFile = 0

foreach ($service in $services) {
    $currentFile++
    $fileName = Split-Path $service -Leaf
    Write-Host "[$currentFile/$totalFiles] Migrating $fileName..." -ForegroundColor Yellow
    
    if (-not (Test-Path $service)) {
        Write-Host "  File not found: $service" -ForegroundColor Red
        continue
    }
    
    # Read file content
    $content = Get-Content $service -Raw
    
    # STEP 1: Update imports
    $content = $content -replace "import 'package:cloud_firestore/cloud_firestore\.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';"
    $content = $content -replace "import '\.\./constants/firestore_constants\.dart';", "import '../constants/database_constants.dart';"
    $content = $content -replace "FirestoreConstants\.", "DatabaseConstants."
    
    # STEP 2: Update class fields and constructor
    $content = $content -replace "final FirebaseFirestore _firestore;", "final SupabaseClient _supabase;"
    $content = $content -replace "FirebaseFirestore\? firestore", "SupabaseClient? supabase"
    $content = $content -replace "_firestore = firestore \?\? FirebaseFirestore\.instance", "_supabase = supabase ?? Supabase.instance.client"
    
    # STEP 3: Update collection references to table references
    $content = $content -replace "\.collection\(([^)]+)\)\.snapshots\(\)", ".from(`$1).stream(primaryKey: ['id'])"
    $content = $content -replace "_firestore\.collection\(", "_supabase.from("
    
    # STEP 4: Update queries
    # Stream queries
    $content = $content -replace "\.snapshots\(\)\.map\(", ".stream(primaryKey: ['id']).map("
    $content = $content -replace "snapshot\.docs\.map\(\(doc\) => ", "data.map((item) => "
    $content = $content -replace "\.fromMap\(doc\.data\(\)\)\)", ".fromMap(item))"
    
    # Get single document
    $content = $content -replace "\.doc\(([^)]+)\)\.get\(\)", ".select().eq('id', `$1).maybeSingle()"
    $content = $content -replace "doc\.exists && doc\.data\(\) != null", "data != null"
    $content = $content -replace "\.fromMap\(doc\.data\(\)!\)", ".fromMap(data)"
    
    # Where clauses
    $content = $content -replace "\.where\(([^,]+), isEqualTo: ([^)]+)\)", ".eq(`$1, `$2)"
    $content = $content -replace "\.where\(([^,]+), isGreaterThanOrEqualTo: ([^)]+)\)", ".gte(`$1, `$2)"
    $content = $content -replace "\.where\(([^,]+), isLessThan: ([^)]+)\)", ".lt(`$1, `$2)"
    $content = $content -replace "\.where\(([^,]+), isLessThanOrEqualTo: ([^)]+)\)", ".lte(`$1, `$2)"
    $content = $content -replace "\.where\(([^,]+), arrayContains: ([^)]+)\)", ".contains(`$1, [`$2])"
    $content = $content -replace "\.where\(([^,]+), arrayContainsAny: ([^)]+)\)", ".overlaps(`$1, `$2)"
    
    # Order by
    $content = $content -replace "\.orderBy\(([^,]+), descending: true\)", ".order(`$1, ascending: false)"
    $content = $content -replace "\.orderBy\(([^,]+)\)", ".order(`$1)"
    
    # Limit
    $content = $content -replace "\.limit\(([^)]+)\)", ".limit(`$1)"
    
    # STEP 5: Update CRUD operations
    # Set/Insert
    $content = $content -replace "\.doc\(([^)]+)\)\.set\(([^)]+)\)", ".insert(`$2)"
    
    # Update
    $content = $content -replace "\.doc\(([^)]+)\)\.update\(([^)]+)\)", ".update(`$2).eq('id', `$1)"
    
    # Delete
    $content = $content -replace "\.doc\(([^)]+)\)\.delete\(\)", ".delete().eq('id', `$1)"
    
    # STEP 6: Update Timestamp references
    $content = $content -replace "Timestamp\.now\(\)", "DateTime.now().toIso8601String()"
    $content = $content -replace "Timestamp\.fromDate\(([^)]+)\)", "`$1.toIso8601String()"
    $content = $content -replace "FieldValue\.serverTimestamp\(\)", "DateTime.now().toIso8601String()"
    
    # STEP 7: Update count queries
    $content = $content -replace "\.count\(\)\.get\(\)", ".select('id')"
    $content = $content -replace "snapshot\.count \?\? 0", "data.length"
    
    # STEP 8: Update batch operations (convert to list inserts)
    $content = $content -replace "WriteBatch batch = _firestore\.batch\(\);", "// Batch operations converted to bulk insert"
    $content = $content -replace "batch\.set\(", "// batch.set("
    $content = $content -replace "await batch\.commit\(\);", "// Use .insert([...]) for bulk operations"
    
    # STEP 9: Update FieldPath references
    $content = $content -replace "FieldPath\.documentId", "'id'"
    $content = $content -replace "whereIn:", "in_:"
    
    # STEP 10: Fix stream map signatures
    $content = $content -replace "\.map\(\(snapshot\) =>", ".map((data) =>"
    $content = $content -replace "snapshot\.docs", "data"
    
    # Write updated content
    Set-Content $service -Value $content -NoNewline
    
    Write-Host "  Migrated successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "Migration Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Post-Migration Steps:" -ForegroundColor Cyan
Write-Host "  1. Review changes: git diff" -ForegroundColor White
Write-Host "  2. Run analysis: flutter analyze" -ForegroundColor White
Write-Host "  3. Fix any remaining issues manually" -ForegroundColor White
Write-Host "  4. Commit changes" -ForegroundColor White
Write-Host ""
Write-Host "Manual Review Required:" -ForegroundColor Yellow
Write-Host "  - WriteBatch operations need manual conversion" -ForegroundColor White
Write-Host "  - Complex queries may need adjustment" -ForegroundColor White
Write-Host "  - Stream primaryKey may need customization" -ForegroundColor White
Write-Host ""

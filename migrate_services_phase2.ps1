# Phase 2: Manual Refinement Script
# Fixes remaining issues from automated migration

Write-Host "Starting Phase 2: Manual refinements..." -ForegroundColor Cyan

$services = @(
    "lib\core\services\menu_service.dart",
    "lib\core\services\order_service.dart",
    "lib\core\services\parent_service.dart",
    "lib\core\services\student_service.dart",
    "lib\core\services\topup_service.dart",
    "lib\core\services\weekly_menu_service.dart",
    "lib\core\services\weekly_menu_analytics_service.dart"
)

foreach ($service in $services) {
    $fileName = Split-Path $service -Leaf
    Write-Host "Refining $fileName..." -ForegroundColor Yellow
    
    $content = Get-Content $service -Raw
    
    # Fix remaining _firestore references
    $content = $content -replace "_firestore", "_supabase"
    
    # Fix .collection() calls that weren't caught
    $content = $content -replace "\.collection\(", ".from("
    
    # Fix table name constants that don't exist
    $content = $content -replace "DatabaseConstants\.menuItemsCollection", "'menu_items'"
    $content = $content -replace "DatabaseConstants\.studentsCollection", "'students'"
    $content = $content -replace "DatabaseConstants\.parentsCollection", "'parents'"
    $content = $content -replace "DatabaseConstants\.ordersCollection", "'orders'"
    $content = $content -replace "DatabaseConstants\.topupsCollection", "'topups'"
    $content = $content -replace "DatabaseConstants\.weeklyMenusCollection", "'weekly_menus'"
    $content = $content -replace "DatabaseConstants\.menuAnalyticsCollection", "'menu_analytics'"
    
    # Fix stream calls
    $content = $content -replace "\.from\(([^)]+)\)\.stream\(primaryKey: \['id'\]\)\.order\(", ".from(`$1).stream(primaryKey: ['id']).order("
    
    # Fix snapshot.docs patterns that weren't caught
    $content = $content -replace "snapshot\.docs\s+\.map", "data.map"
    
    # Fix doc variable to data
    $content = $content -replace "final doc = await", "final data = await"
    $content = $content -replace "if \(doc\.exists", "if (data != null"
    $content = $content -replace "doc\.data\(\)", "data"
    
    # Fix aggregate queries
    $content = $content -replace "\.select\('id'\)\.length", ".select('id')"
    $content = $content -replace "data\.length", "(data as List).length"
    
    Set-Content $service -Value $content -NoNewline
    Write-Host "  Done" -ForegroundColor Green
}

Write-Host ""
Write-Host "Phase 2 Complete!" -ForegroundColor Green
Write-Host "Run flutter analyze again to check progress" -ForegroundColor Cyan

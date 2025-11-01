# Phase 3: Fix Supabase Stream Query Syntax
# Properly format all stream and query calls

Write-Host "Starting Phase 3: Fix stream queries..." -ForegroundColor Cyan

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
    Write-Host "Fixing $fileName..." -ForegroundColor Yellow
    
    $content = Get-Content $service -Raw
    
    # Fix: .from('table').order(...).snapshots() -> .from('table').stream(primaryKey: ['id']).order(...)
    $content = $content -replace "\.from\(([^)]+)\)\.order\(([^)]+)\)\.snapshots\(\)", ".from(`$1).stream(primaryKey: ['id']).order(`$2)"
    
    # Fix: .from('table').eq(...).order(...).snapshots() -> .from('table').stream(primaryKey: ['id']).eq(...).order(...)
    $content = $content -replace "\.from\(([^)]+)\)\.eq\(([^)]+)\)\.order\(([^)]+)\)\.snapshots\(\)", ".from(`$1).stream(primaryKey: ['id']).eq(`$2).order(`$3)"
    
    # Fix: .from('table').eq(...).snapshots() -> .from('table').stream(primaryKey: ['id']).eq(...)
    $content = $content -replace "\.from\(([^)]+)\)\.eq\(([^)]+)\)\.snapshots\(\)", ".from(`$1).stream(primaryKey: ['id']).eq(`$2)"
    
    # Fix: .doc(id).snapshots() -> .stream(primaryKey: ['id']).eq('id', id)
    $content = $content -replace "\.from\(([^)]+)\)\.doc\(([^)]+)\)\.snapshots\(\)", ".from(`$1).stream(primaryKey: ['id']).eq('id', `$2)"
    
    # Fix: .doc(id).set(data) -> .insert(data)
    $content = $content -replace "\.from\(([^)]+)\)\.doc\(([^)]+)\)\.set\(([^)]+)\)", ".from(`$1).insert(`$3)"
    
    # Fix: .doc(id).update(data) -> .update(data).eq('id', id)
    $content = $content -replace "\.from\(([^)]+)\)\.doc\(([^)]+)\)\.update\(([^)]+)\)", ".from(`$1).update(`$3).eq('id', `$2)"
    
    # Fix: .doc(id).delete() -> .delete().eq('id', id)
    $content = $content -replace "\.from\(([^)]+)\)\.doc\(([^)]+)\)\.delete\(\)", ".from(`$1).delete().eq('id', `$2)"
    
    # Fix: .eq('field', value).limit(n).get() -> .select().eq('field', value).limit(n)
    $content = $content -replace "\.eq\(([^)]+)\)\.limit\(([^)]+)\)\.get\(\)", ".select().eq(`$1).limit(`$2)"
    
    # Fix: .limit(n).get() -> .select().limit(n)
    $content = $content -replace "\.from\(([^)]+)\)\.limit\(([^)]+)\)\.get\(\)", ".from(`$1).select().limit(`$2)"
    
    # Fix snapshot variable references in streams
    $content = $content -replace "snapshot\.exists && snapshot\.data\(\) != null", "item != null"
    $content = $content -replace "MenuItem\.fromMap\(snapshot\.data\(\)!\)", "MenuItem.fromMap(item)"
    
    # Fix data.isNotEmpty checks (for query results)
    $content = $content -replace "if \(data\.isNotEmpty\)", "if ((data as List).isNotEmpty)"
    $content = $content -replace "data\.first\.data\(\)", "(data as List).first"
    
    Set-Content $service -Value $content -NoNewline
    Write-Host "  Done" -ForegroundColor Green
}

Write-Host ""
Write-Host "Phase 3 Complete!" -ForegroundColor Green
Write-Host "Checking compilation..." -ForegroundColor Cyan

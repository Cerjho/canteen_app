# ========================================
# Firebase Firestore Rules Deployment Script
# ========================================
# Purpose: Deploy updated Firestore security rules to Firebase
# Usage: .\deploy_firestore_rules.ps1

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Firebase Firestore Rules Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
Write-Host "Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue

if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Firebase CLI first:" -ForegroundColor Yellow
    Write-Host "  npm install -g firebase-tools" -ForegroundColor White
    Write-Host ""
    Write-Host "Or visit: https://firebase.google.com/docs/cli#install_the_firebase_cli" -ForegroundColor White
    exit 1
}

Write-Host "✅ Firebase CLI found" -ForegroundColor Green
Write-Host ""

# Check if firestore.rules exists
if (-not (Test-Path "firestore.rules")) {
    Write-Host "❌ firestore.rules file not found!" -ForegroundColor Red
    Write-Host "Please run this script from the admin_app directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ firestore.rules file found" -ForegroundColor Green
Write-Host ""

# Show what will be deployed
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Rules Summary:" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Changes being deployed:" -ForegroundColor Yellow
Write-Host "  • Parents can update 'children' array" -ForegroundColor White
Write-Host "  • Parents can link unlinked students" -ForegroundColor White
Write-Host "  • Parents can unlink their own students" -ForegroundColor White
Write-Host "  • Parents can edit student allergies & dietary restrictions" -ForegroundColor White
Write-Host ""
Write-Host "Security maintained:" -ForegroundColor Green
Write-Host "  ✅ Parents cannot edit student names, grades, IDs" -ForegroundColor White
Write-Host "  ✅ Parents cannot modify balances" -ForegroundColor White
Write-Host "  ✅ Parents cannot link already-linked students" -ForegroundColor White
Write-Host "  ✅ Admins retain full access" -ForegroundColor White
Write-Host ""

# Confirm deployment
Write-Host "================================================" -ForegroundColor Cyan
$confirmation = Read-Host "Deploy these rules to Firebase? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Deploying Firestore Rules..." -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Deploy rules
firebase deploy --only firestore:rules

# Check deployment result
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "✅ Deployment Successful!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Verify in Firebase Console:" -ForegroundColor White
    Write-Host "     https://console.firebase.google.com/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Test parent linking:" -ForegroundColor White
    Write-Host "     • Login as parent" -ForegroundColor Gray
    Write-Host "     • Link a student using student ID" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Test parent editing:" -ForegroundColor White
    Write-Host "     • Navigate to linked student" -ForegroundColor Gray
    Write-Host "     • Edit allergies/dietary restrictions" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Monitor for errors:" -ForegroundColor White
    Write-Host "     • Check Firebase Console logs" -ForegroundColor Gray
    Write-Host "     • Watch for permission denied errors" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "❌ Deployment Failed!" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "  • Not logged into Firebase CLI (run: firebase login)" -ForegroundColor White
    Write-Host "  • Wrong Firebase project selected (run: firebase use [project-id])" -ForegroundColor White
    Write-Host "  • Syntax error in firestore.rules file" -ForegroundColor White
    Write-Host "  • Insufficient permissions for deployment" -ForegroundColor White
    Write-Host ""
    Write-Host "For help:" -ForegroundColor Yellow
    Write-Host "  firebase --help" -ForegroundColor White
    Write-Host "  firebase deploy --help" -ForegroundColor White
    Write-Host ""
}

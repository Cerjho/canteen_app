# Supabase Deployment Helper Script for Windows
# This script helps you deploy Supabase Edge Functions quickly

Write-Host "🚀 Supabase Edge Functions Deployment Helper" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if Supabase CLI is installed
$supabaseInstalled = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseInstalled) {
    Write-Host "❌ Supabase CLI is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  npm install -g supabase" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ Supabase CLI found" -ForegroundColor Green
Write-Host ""

# Menu
Write-Host "What would you like to do?" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Deploy all functions" -ForegroundColor White
Write-Host "2. Deploy order_confirmation" -ForegroundColor White
Write-Host "3. Deploy paymongo_webhook" -ForegroundColor White
Write-Host "4. Deploy stripe_webhook" -ForegroundColor White
Write-Host "5. Deploy set_user_role" -ForegroundColor White
Write-Host "6. Test functions locally" -ForegroundColor White
Write-Host "7. View function logs" -ForegroundColor White
Write-Host "8. Set environment secrets" -ForegroundColor White
Write-Host "9. Check deployment status" -ForegroundColor White
Write-Host "0. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (0-9)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "📦 Deploying all functions..." -ForegroundColor Yellow
        supabase functions deploy
        Write-Host ""
        Write-Host "✅ Deployment complete!" -ForegroundColor Green
    }
    "2" {
        Write-Host ""
        Write-Host "📦 Deploying order_confirmation..." -ForegroundColor Yellow
        supabase functions deploy order_confirmation
        Write-Host ""
        Write-Host "✅ Deployment complete!" -ForegroundColor Green
    }
    "3" {
        Write-Host ""
        Write-Host "📦 Deploying paymongo_webhook..." -ForegroundColor Yellow
        supabase functions deploy paymongo_webhook
        Write-Host ""
        Write-Host "✅ Deployment complete!" -ForegroundColor Green
    }
    "4" {
        Write-Host ""
        Write-Host "📦 Deploying stripe_webhook..." -ForegroundColor Yellow
        supabase functions deploy stripe_webhook
        Write-Host ""
        Write-Host "✅ Deployment complete!" -ForegroundColor Green
    }
    "5" {
        Write-Host ""
        Write-Host "📦 Deploying set_user_role..." -ForegroundColor Yellow
        supabase functions deploy set_user_role
        Write-Host ""
        Write-Host "✅ Deployment complete!" -ForegroundColor Green
    }
    "6" {
        Write-Host ""
        Write-Host "🧪 Starting local Supabase environment..." -ForegroundColor Yellow
        Write-Host "This will start all Supabase services locally" -ForegroundColor White
        Write-Host ""
        supabase start
        Write-Host ""
        Write-Host "✅ Local environment running!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Test functions at: http://localhost:54321/functions/v1/FUNCTION_NAME" -ForegroundColor Cyan
    }
    "7" {
        Write-Host ""
        Write-Host "Which function logs do you want to view?" -ForegroundColor Cyan
        Write-Host "1. order_confirmation" -ForegroundColor White
        Write-Host "2. paymongo_webhook" -ForegroundColor White
        Write-Host "3. stripe_webhook" -ForegroundColor White
        Write-Host "4. set_user_role" -ForegroundColor White
        Write-Host "5. All functions" -ForegroundColor White
        Write-Host ""
        $logChoice = Read-Host "Enter choice (1-5)"
        
        $functionName = switch ($logChoice) {
            "1" { "order_confirmation" }
            "2" { "paymongo_webhook" }
            "3" { "stripe_webhook" }
            "4" { "set_user_role" }
            "5" { $null }
        }
        
        Write-Host ""
        if ($functionName) {
            Write-Host "📋 Viewing logs for $functionName..." -ForegroundColor Yellow
            supabase functions logs $functionName --follow
        } else {
            Write-Host "📋 Viewing logs for all functions..." -ForegroundColor Yellow
            supabase functions logs --follow
        }
    }
    "8" {
        Write-Host ""
        Write-Host "🔐 Setting environment secrets..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This will help you set required secrets one by one" -ForegroundColor White
        Write-Host "Press Enter to skip any secret" -ForegroundColor Gray
        Write-Host ""
        
        # PayMongo
        $paymongoSecret = Read-Host "PayMongo Secret Key (PAYMONGO_SECRET)"
        if ($paymongoSecret) {
            supabase secrets set PAYMONGO_SECRET=$paymongoSecret
            Write-Host "✅ PAYMONGO_SECRET set" -ForegroundColor Green
        }
        
        $paymongoWebhook = Read-Host "PayMongo Webhook Secret (PAYMONGO_WEBHOOK_SECRET)"
        if ($paymongoWebhook) {
            supabase secrets set PAYMONGO_WEBHOOK_SECRET=$paymongoWebhook
            Write-Host "✅ PAYMONGO_WEBHOOK_SECRET set" -ForegroundColor Green
        }
        
        # Stripe
        $stripeSecret = Read-Host "Stripe Secret Key (STRIPE_SECRET)"
        if ($stripeSecret) {
            supabase secrets set STRIPE_SECRET=$stripeSecret
            Write-Host "✅ STRIPE_SECRET set" -ForegroundColor Green
        }
        
        $stripeWebhook = Read-Host "Stripe Webhook Secret (STRIPE_WEBHOOK_SECRET)"
        if ($stripeWebhook) {
            supabase secrets set STRIPE_WEBHOOK_SECRET=$stripeWebhook
            Write-Host "✅ STRIPE_WEBHOOK_SECRET set" -ForegroundColor Green
        }
        
        # Order Confirmation
        $orderSecret = Read-Host "Order Confirmation Secret (ORDER_CONFIRMATION_SECRET)"
        if ($orderSecret) {
            supabase secrets set ORDER_CONFIRMATION_SECRET=$orderSecret
            Write-Host "✅ ORDER_CONFIRMATION_SECRET set" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "✅ Secrets configuration complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "To view all secrets:" -ForegroundColor Cyan
        Write-Host "  supabase secrets list" -ForegroundColor White
    }
    "9" {
        Write-Host ""
        Write-Host "📊 Checking deployment status..." -ForegroundColor Yellow
        Write-Host ""
        
        # List functions
        Write-Host "Deployed functions:" -ForegroundColor Cyan
        supabase functions list
        
        Write-Host ""
        Write-Host "Environment secrets:" -ForegroundColor Cyan
        supabase secrets list
        
        Write-Host ""
        Write-Host "Project info:" -ForegroundColor Cyan
        supabase projects list
    }
    "0" {
        Write-Host ""
        Write-Host "👋 Goodbye!" -ForegroundColor Cyan
        exit 0
    }
    default {
        Write-Host ""
        Write-Host "❌ Invalid choice. Please run the script again." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "📚 For more help, see:" -ForegroundColor Cyan
Write-Host "  - supabase/functions/README.md" -ForegroundColor White
Write-Host "  - MIGRATION_SUMMARY.md" -ForegroundColor White
Write-Host ""

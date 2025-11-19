# EQGT_Diagnose_Pricing.ps1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# Purpose: Diagnostic script to troubleshoot why prices show as TBD
# Version: 2.0
# Release: 2025-01-XX

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configModuleLoaded = $false
try {
    Import-Module (Join-Path $scriptRoot "EQGT_Config.psm1") -Force -ErrorAction Stop
    $configModuleLoaded = $true
} catch {
    Write-Warning "Could not load EQGT_Config module. Using defaults."
}

if (-not $configModuleLoaded) {
    function Get-EQGTPigParseCachePath { return Join-Path $scriptRoot 'EQGT_cache_pigparse_green.json' }
    function Get-EQGTPigParseApiUrl { return "https://www.pigparse.org" }
    function Get-EQGTScriptRoot { return $scriptRoot }
}

Write-Host "`n=== EQGT Pricing Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check cache file
Write-Host "1. Checking cache file..." -ForegroundColor Yellow
$cachePath = Get-EQGTPigParseCachePath
Write-Host "   Cache path: $cachePath" -ForegroundColor Gray

if (Test-Path -LiteralPath $cachePath) {
    Write-Host "   ✓ Cache file exists" -ForegroundColor Green
    try {
        $cacheContent = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
        if ($cacheContent.timestamp) {
            $cacheDate = [DateTime]::Parse($cacheContent.timestamp)
            $age = (Get-Date) - $cacheDate
            Write-Host "   Cache age: $($age.Days) days, $($age.Hours) hours" -ForegroundColor $(if ($age.Days -lt 7) { "Green" } else { "Yellow" })
            
            if ($cacheContent.data) {
                $itemCount = if ($cacheContent.data -is [Array]) { $cacheContent.data.Count } else { "Unknown" }
                Write-Host "   Items in cache: $itemCount" -ForegroundColor Green
            } else {
                Write-Host "   ⚠ Cache file exists but has no data" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ⚠ Cache file exists but missing timestamp" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ✗ Cache file is corrupted: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Cache file does not exist (first run?)" -ForegroundColor Red
}

# 2. Check internet connectivity
Write-Host "`n2. Checking internet connectivity..." -ForegroundColor Yellow
try {
    $testUrl = "https://www.google.com"
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   ✓ Internet connection OK" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Internet connection failed: $_" -ForegroundColor Red
    Write-Host "   This will prevent API calls from working." -ForegroundColor Yellow
}

# 3. Comprehensive DNS testing for PigParse domains
Write-Host "`n3. Comprehensive DNS testing for PigParse domains..." -ForegroundColor Yellow

# 3a. Test root domain DNS
Write-Host "   3a. Testing root domain (pigparse.org)..." -ForegroundColor Gray
try {
    $rootDns = Resolve-DnsName -Name "pigparse.org" -Type A -ErrorAction Stop
    if ($rootDns) {
        $rootIP = ($rootDns | Select-Object -First 1).IPAddress
        Write-Host "      ✓ pigparse.org resolves to: $rootIP" -ForegroundColor Green
    }
} catch {
    Write-Host "      ✗ pigparse.org DNS lookup failed: $_" -ForegroundColor Red
}

# 3b. Test NS records
Write-Host "   3b. Testing NS records..." -ForegroundColor Gray
try {
    $nsRecords = Resolve-DnsName -Name "pigparse.org" -Type NS -ErrorAction Stop
    if ($nsRecords) {
        Write-Host "      ✓ NS records found:" -ForegroundColor Green
        $nsRecords | Where-Object { $_.Type -eq 'NS' } | ForEach-Object {
            Write-Host "        - $($_.NameHost)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "      ✗ NS record lookup failed: $_" -ForegroundColor Red
}

# 3c. Test api.pigparse.org (expected to fail)
Write-Host "   3c. Testing api.pigparse.org..." -ForegroundColor Gray
try {
    $apiDns = Resolve-DnsName -Name "api.pigparse.org" -Type A -ErrorAction Stop
    if ($apiDns) {
        $apiIP = ($apiDns | Select-Object -First 1).IPAddress
        Write-Host "      ✓ api.pigparse.org resolves to: $apiIP" -ForegroundColor Green
    }
} catch {
    Write-Host "      ✗ api.pigparse.org DNS resolution failed (expected)" -ForegroundColor Yellow
    Write-Host "        Error: $_" -ForegroundColor Gray
}

# 3d. Test www.pigparse.org (should work)
Write-Host "   3d. Testing www.pigparse.org..." -ForegroundColor Gray
try {
    $wwwDns = Resolve-DnsName -Name "www.pigparse.org" -Type A -ErrorAction Stop
    if ($wwwDns) {
        $wwwIP = ($wwwDns | Select-Object -First 1).IPAddress
        Write-Host "      ✓ www.pigparse.org resolves to: $wwwIP" -ForegroundColor Green
        $cname = $wwwDns | Where-Object { $_.Type -eq 'CNAME' } | Select-Object -First 1
        if ($cname) {
            Write-Host "        CNAME: $($cname.NameHost)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "      ✗ www.pigparse.org DNS lookup failed: $_" -ForegroundColor Red
}

# 3e. Test DNS cache
Write-Host "   3e. Checking DNS cache..." -ForegroundColor Gray
$dnsCache = Get-DnsClientCache | Where-Object { $_.Entry -like "*pigparse*" }
if ($dnsCache) {
    Write-Host "      ✓ Found cached entries:" -ForegroundColor Green
    $dnsCache | Select-Object -First 5 | ForEach-Object {
        Write-Host "        - $($_.Entry): $($_.Data)" -ForegroundColor Gray
    }
} else {
    Write-Host "      ⚠ No cached entries found" -ForegroundColor Yellow
}

# 4. Test network connectivity
Write-Host "`n4. Testing network connectivity..." -ForegroundColor Yellow

# 4a. Test api.pigparse.org connectivity (expected to fail)
Write-Host "   4a. Testing api.pigparse.org:443..." -ForegroundColor Gray
try {
    $apiNetTest = Test-NetConnection -ComputerName "api.pigparse.org" -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
    if ($apiNetTest.TcpTestSucceeded) {
        Write-Host "      ✓ api.pigparse.org:443 is reachable" -ForegroundColor Green
    } else {
        Write-Host "      ✗ api.pigparse.org:443 not reachable (expected)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "      ✗ api.pigparse.org connectivity test failed: $_" -ForegroundColor Yellow
}

# 4b. Test www.pigparse.org connectivity (should work)
Write-Host "   4b. Testing www.pigparse.org:443..." -ForegroundColor Gray
try {
    $wwwNetTest = Test-NetConnection -ComputerName "www.pigparse.org" -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
    if ($wwwNetTest.TcpTestSucceeded) {
        Write-Host "      ✓ www.pigparse.org:443 is reachable" -ForegroundColor Green
    } else {
        Write-Host "      ✗ www.pigparse.org:443 not reachable" -ForegroundColor Red
        if ($wwwNetTest.PingSucceeded) {
            Write-Host "        Host is reachable but port 443 is blocked" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "      ✗ www.pigparse.org connectivity test failed: $_" -ForegroundColor Red
}

# 4c. Test API endpoint on www.pigparse.org
Write-Host "   4c. Testing API endpoint on www.pigparse.org..." -ForegroundColor Gray
try {
    $testApi = Invoke-RestMethod -Uri "https://www.pigparse.org/api/item/getall/Green" -TimeoutSec 10 -ErrorAction Stop
    if ($testApi) {
        $itemCount = if ($testApi -is [Array]) { $testApi.Count } else { "Unknown" }
        Write-Host "      ✓ API endpoint works! Response: $itemCount items" -ForegroundColor Green
        Write-Host "        → RECOMMENDATION: Use www.pigparse.org instead of api.pigparse.org" -ForegroundColor Cyan
    }
} catch {
    Write-Host "      ✗ API endpoint test failed: $_" -ForegroundColor Red
}

# 5. Check PigParse API endpoint
Write-Host "`n5. Testing PigParse API endpoint..." -ForegroundColor Yellow
$apiUrl = Get-EQGTPigParseApiUrl
$fullApiUrl = "$apiUrl/api/item/getall/Green"
Write-Host "   API URL: $fullApiUrl" -ForegroundColor Gray

try {
    Write-Host "   Attempting API call (this may take 10-20 seconds)..." -ForegroundColor Gray
    $response = Invoke-WebRequest -Uri $fullApiUrl -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✓ API call successful (Status: $($response.StatusCode))" -ForegroundColor Green
        Write-Host "   Response size: $([math]::Round($response.Content.Length / 1MB, 2)) MB" -ForegroundColor Gray
        
        try {
            $jsonData = $response.Content | ConvertFrom-Json
            if ($jsonData -is [Array]) {
                Write-Host "   ✓ JSON parsed successfully - $($jsonData.Count) items" -ForegroundColor Green
            } else {
                Write-Host "   ⚠ JSON parsed but unexpected format" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "   ✗ JSON parsing failed: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "   ⚠ API returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ✗ API call failed: $_" -ForegroundColor Red
    Write-Host "   Error details: $($_.Exception.Message)" -ForegroundColor Gray
    
    if ($_.Exception.Message -match "timeout") {
        Write-Host "   → This appears to be a timeout issue. Try again later." -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "SSL|certificate") {
        Write-Host "   → SSL/certificate issue. Check system date/time." -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "forbidden|403") {
        Write-Host "   → Access forbidden. API may be blocking requests." -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "not found|404") {
        Write-Host "   → Endpoint not found. API endpoint may have changed." -ForegroundColor Yellow
    }
}

# 6. Check PowerShell execution policy
Write-Host "`n6. Checking PowerShell execution policy..." -ForegroundColor Yellow
$execPolicy = Get-ExecutionPolicy
Write-Host "   Current policy: $execPolicy" -ForegroundColor $(if ($execPolicy -ne 'Restricted') { "Green" } else { "Red" })
if ($execPolicy -eq 'Restricted') {
    Write-Host "   ⚠ Execution policy is Restricted - scripts may not run" -ForegroundColor Yellow
    Write-Host "   Fix: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
}

# 7. Check required PowerShell cmdlets
Write-Host "`n7. Checking required PowerShell cmdlets..." -ForegroundColor Yellow
$required = @('ConvertFrom-Json', 'ConvertTo-Json', 'Invoke-WebRequest', 'ConvertFrom-Csv', 'Export-Csv')
$allOk = $true
foreach ($cmdlet in $required) {
    if (Get-Command $cmdlet -ErrorAction SilentlyContinue) {
        Write-Host "   ✓ $cmdlet available" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $cmdlet missing" -ForegroundColor Red
        $allOk = $false
    }
}
if ($allOk) {
    Write-Host "   ✓ All required cmdlets available" -ForegroundColor Green
}

# 8. Test cache read/write
Write-Host "`n8. Testing cache file read/write..." -ForegroundColor Yellow
$testCachePath = Join-Path $scriptRoot "EQGT_test_cache.json"
try {
    $testData = @{ timestamp = (Get-Date).ToString('o'); data = @(@{ n = "Test Item"; a30 = 100 }) }
    $testData | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $testCachePath -Encoding UTF8
    Write-Host "   ✓ Cache write test successful" -ForegroundColor Green
    
    $readBack = Get-Content -LiteralPath $testCachePath | ConvertFrom-Json
    if ($readBack) {
        Write-Host "   ✓ Cache read test successful" -ForegroundColor Green
    }
    Remove-Item -LiteralPath $testCachePath -ErrorAction SilentlyContinue
} catch {
    Write-Host "   ✗ Cache read/write test failed: $_" -ForegroundColor Red
    Write-Host "   → Check file permissions in: $scriptRoot" -ForegroundColor Yellow
}

# 9. Check script files
Write-Host "`n9. Checking EQGT script files..." -ForegroundColor Yellow
$requiredScripts = @(
    'EQGT_Config.psm1',
    'EQGT_PigParse_Scraper.ps1',
    'EQGT_EC_Gem_Pricer.ps1'
)
foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $scriptRoot $script
    if (Test-Path -LiteralPath $scriptPath) {
        Write-Host "   ✓ $script found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $script missing" -ForegroundColor Red
    }
}

# Summary and recommendations
Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $cachePath)) {
    Write-Host "• Cache file doesn't exist. This is normal on first run." -ForegroundColor Yellow
    Write-Host "  The script should create it automatically when it fetches prices." -ForegroundColor Gray
    Write-Host ""
}

Write-Host "• If API calls are failing:" -ForegroundColor Yellow
Write-Host "  1. Check firewall settings - allow PowerShell to access internet" -ForegroundColor Gray
Write-Host "  2. Check if corporate proxy is blocking api.pigparse.org" -ForegroundColor Gray
Write-Host "  3. Try running the script again - API may have been temporarily down" -ForegroundColor Gray
Write-Host "  4. Check system date/time - SSL certificates require correct date" -ForegroundColor Gray
Write-Host ""

Write-Host "• To manually refresh cache:" -ForegroundColor Yellow
Write-Host "  Delete the cache file: $cachePath" -ForegroundColor Gray
Write-Host "  Then run EQGT_EC_Gem_Pricer.ps1 again" -ForegroundColor Gray
Write-Host ""

Write-Host "• If prices still show TBD after fixing issues:" -ForegroundColor Yellow
Write-Host "  Run this diagnostic again and share the output" -ForegroundColor Gray
Write-Host ""

Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host ""



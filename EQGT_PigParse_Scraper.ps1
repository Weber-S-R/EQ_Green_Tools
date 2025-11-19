# EQGT_PigParse_Scraper.ps1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# EverQuest Green Characters: Aedonis, Nebuchadnezzarr, and trader Friartuc
# Purpose: Scrape PigParse website for Green server item prices as a fallback when API is unavailable
# Description: Provides functions to query PigParse Green server bulk item data via /api/item/getall/Green endpoint.
#              Implements 7-day on-disk caching to reduce API load. Used by EQGT_EC_Gem_Pricer.ps1 for price lookups.
# Version: 2.0
# Release: 2025-11-18
# Usage: Internal module - called by EQGT_EC_Gem_Pricer.ps1

# ============================================================================
# SECTION: Module Imports
# ============================================================================

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptRoot) {
    $scriptRoot = Split-Path -Parent $PSCommandPath
}
$configModuleLoaded = $false
try {
    Import-Module (Join-Path $scriptRoot "EQGT_Config.psm1") -Force -ErrorAction Stop
    $configModuleLoaded = $true
} catch {
    Write-Warning "Could not load EQGT_Config module. Using defaults. Error: $_"
}

# Fallback functions if config module not available
if (-not $configModuleLoaded) {
    function Get-EQGTPigParseCachePath { return Join-Path $scriptRoot 'EQGT_cache_pigparse_green.json' }
    function Get-EQGTPigParseApiUrl { return "https://www.pigparse.org" }
}

# Script parameters removed - script is dot-sourced, not executed directly

# ============================================================================
# SECTION: Helper Functions
# ============================================================================

function Write-Info { param([string]$m) Write-Host $m -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host $m -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host $m -ForegroundColor Yellow }

# ============================================================================
# SECTION: Cache Configuration
# ============================================================================

# Simple in-session cache
$script:PigParseGreenAllCache = $null
$script:CacheTtlDays = 7  # 7-day cache as per user requirement

# ============================================================================
# SECTION: Cache Management Functions
# ============================================================================

function Get-CachePath {
    return Get-EQGTPigParseCachePath
}

function Read-GreenCache {
    $path = Get-CachePath
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        $obj = Get-Content -LiteralPath $path | ConvertFrom-Json -AsHashtable
        if (-not $obj) { return $null }
        $ts = Get-Date ($obj.timestamp)
        if ((Get-Date) - $ts -lt (New-TimeSpan -Days $script:CacheTtlDays)) {
            return $obj.data
        }
    } catch {}
    return $null
}

function Write-GreenCache {
    param([Parameter(Mandatory=$true)]$Data)
    $path = Get-CachePath
    $obj = @{ timestamp = (Get-Date).ToString('o'); data = $Data }
    try { $obj | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8 } catch {}
}

# ============================================================================
# SECTION: HTTP Request Functions
# ============================================================================

function Invoke-EQGTHttp {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [int]$MaxRetries = 2,
        [int]$TimeoutSec = 20
    )
    $retryCount = 0
    while ($retryCount -le $MaxRetries) {
        try {
            # Use Invoke-RestMethod instead of Invoke-WebRequest for better JSON handling
            # Invoke-RestMethod automatically parses JSON and handles errors differently
            $result = Invoke-RestMethod -Uri $Uri -Headers @{ 'User-Agent' = 'EQGT-EC-Gem-Pricer/2.0' } -TimeoutSec $TimeoutSec -ErrorAction Stop
            # Return as hashtable with Content property for compatibility
            return @{ Content = $result }
        } catch {
            $retryCount++
            if ($retryCount -gt $MaxRetries) {
                Write-Warn "API call failed after $($MaxRetries + 1) attempts: $_"
                return $null
            }
            # Brief delay before retry
            Start-Sleep -Milliseconds 500
        }
    }
    return $null
}

# ============================================================================
# SECTION: Price Lookup Functions
# ============================================================================

function Get-PigParseGreenPriceRowHtml {
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)][string]$ItemName
    )
    # Try a few plausible URLs used by PigParse for prices/search
    $candidateUris = @(
        ("https://www.pigparse.org/prices?server=green&search=" + [System.Web.HttpUtility]::UrlEncode($ItemName)),
        ("https://www.pigparse.org/green/prices?search=" + [System.Web.HttpUtility]::UrlEncode($ItemName)),
        ("https://www.pigparse.org/search?server=green&q=" + [System.Web.HttpUtility]::UrlEncode($ItemName)),
        "https://www.pigparse.org/green/prices"
    )
    foreach ($u in $candidateUris) {
        $resp = Invoke-EQGTHttp -Uri $u
        $html = $null
        if ($resp -and $resp.Content) { $html = $resp.Content }
        if (-not $html) {
            $html = Invoke-EdgeDumpDom -Uri $u
        }
        # Find a table row containing the item name
        $pattern = "<tr[\s\S]*?>[\s\S]*?" + [Regex]::Escape($ItemName) + "[\s\S]*?</tr>"
        $m = [Regex]::Match($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Value }
    }
    return $null
}

function Invoke-EdgeDumpDom {
    param([Parameter(Mandatory=$true)][string]$Uri)
    $edgePaths = @(
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'
    )
    foreach ($p in $edgePaths) {
        if (Test-Path -LiteralPath $p) {
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $p
                $psi.Arguments = "--headless=new --disable-gpu --dump-dom --virtual-time-budget=8000 `"$Uri`""
                $psi.RedirectStandardOutput = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                $proc = [System.Diagnostics.Process]::Start($psi)
                $out = $proc.StandardOutput.ReadToEnd()
                $proc.WaitForExit()
                if ($out -and $out.Length -gt 0) { return $out }
            } catch { continue }
        }
    }
    return $null
}

function Get-PigParseGreenPriceJson {
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory=$true)][string]$ItemName)
    $jsonUris = @(
        ("https://www.pigparse.org/api/search?server=green&q=" + [System.Web.HttpUtility]::UrlEncode($ItemName) + "&limit=1"),
        ("https://www.pigparse.org/api/prices?server=green&search=" + [System.Web.HttpUtility]::UrlEncode($ItemName) + "&limit=1"),
        ("https://www.pigparse.org/prices?server=green&search=" + [System.Web.HttpUtility]::UrlEncode($ItemName) + "&format=json&limit=1"),
        ("https://www.pigparse.org/green/prices?search=" + [System.Web.HttpUtility]::UrlEncode($ItemName) + "&format=json&limit=1"),
        # Bulk list fallback (filter locally)
        "https://www.pigparse.org/prices?server=green&format=json"
    )
    foreach ($u in $jsonUris) {
        try {
            $resp = Invoke-EQGTHttp -Uri $u
            if (-not $resp -or -not $resp.Content) { continue }
            $data = $resp.Content | ConvertFrom-Json
            if ($data) { return $data }
        } catch { continue }
    }
    return $null
}

function Get-PigParseGreenAllItems {
    if ($script:PigParseGreenAllCache) { return $script:PigParseGreenAllCache }
    $disk = Read-GreenCache
    if ($disk) { $script:PigParseGreenAllCache = $disk; return $disk }
    
    # Cache expired or missing - trigger cleanup before fetching new cache
    $cachePath = Get-CachePath
    $cacheExpired = $false
    if (Test-Path -LiteralPath $cachePath) {
        try {
            $cacheContent = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -AsHashtable
            if ($cacheContent.timestamp) {
                $cacheDate = Get-Date ($cacheContent.timestamp)
                $age = (Get-Date) - $cacheDate
                if ($age.Days -ge 7) {
                    $cacheExpired = $true
                }
            }
        } catch {
            $cacheExpired = $true
        }
    } else {
        $cacheExpired = $true
    }
    
    # Auto-cleanup old output files when cache expires (scheduled cleanup)
    if ($cacheExpired) {
        Write-Info "Cache expired or missing - running scheduled cleanup of old output files..."
        try {
            $cleanupScript = Join-Path $scriptRoot "EQGT_Cleanup_Output_Files.ps1"
            if (Test-Path -LiteralPath $cleanupScript) {
                & $cleanupScript -Force -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {
            # Silently continue if cleanup fails - don't block cache generation
        }
    }
    
    # No cache exists - need to fetch from API
    Write-Info "No cache found - fetching fresh price data from PigParse API..."
    Write-Info "This may take 15-30 seconds (downloading ~9,000 items, ~3MB)..."
    Write-Info "Please wait, this only happens once every 7 days..."
    
    $baseUrl = Get-EQGTPigParseApiUrl
    # Construct full API URL
    if ($baseUrl -match 'pigparse\.org$') {
        $u = "$baseUrl/api/item/getall/Green"
    } elseif ($baseUrl -match '/$') {
        $u = "$baseUrl" + 'api/item/getall/Green'
    } else {
        $u = "$baseUrl/api/item/getall/Green"
    }
    
    $startTime = Get-Date
    Write-Info "Connecting to API..."
    
    # Use retry logic built into Invoke-EQGTHttp
    # Invoke-RestMethod returns parsed JSON directly, wrapped in Content property for compatibility
    $resp = Invoke-EQGTHttp -Uri $u -MaxRetries 2 -TimeoutSec 30
    
    if (-not $resp -or -not $resp.Content) {
        return $null
    }
    
    $downloadTime = (Get-Date) - $startTime
    Write-Info "Download complete ($([math]::Round($downloadTime.TotalSeconds, 1)) seconds). Processing data..."
    
    try {
        # Invoke-RestMethod already parsed the JSON, so Content is the data directly
        $data = $resp.Content
        if ($data -and ($data.Count -gt 0 -or $data -is [Array])) {
            Write-Info "Saving cache file (this speeds up future runs)..."
            $script:PigParseGreenAllCache = $data
            Write-GreenCache -Data $data
            $totalTime = (Get-Date) - $startTime
            Write-Ok "Cache created successfully! Loaded $($data.Count) items in $([math]::Round($totalTime.TotalSeconds, 1)) seconds."
            return $data
        } else {
            Write-Warn "API returned data but result is empty."
        }
    } catch {
        Write-Warn "Failed to process API response: $_"
        Write-Warn "API may have returned an error message instead of price data."
    }
    return $null
}

function Parse-PriceFromRowHtml {
    [OutputType([decimal])]
    param([Parameter(Mandatory=$true)][string]$RowHtml)
    # Extract numbers that look like average / median platinum values
    $clean = ($RowHtml -replace "\s+", " ")
    # Try to find a number near keywords
    $avg = [Regex]::Match($clean, "(?i)(avg|average|mean)[^0-9]*([0-9]+)")
    if ($avg.Success) { return [decimal]$avg.Groups[2].Value }
    $med = [Regex]::Match($clean, "(?i)(median)[^0-9]*([0-9]+)")
    if ($med.Success) { return [decimal]$med.Groups[2].Value }
    # Otherwise pick the largest reasonable integer in the row as a heuristic
    $nums = [Regex]::Matches($clean, "\b[0-9]{1,6}\b") | ForEach-Object { [int]$_.Value }
    if ($nums.Count -gt 0) { return [decimal]($nums | Sort-Object -Descending | Select-Object -First 1) }
    return $null
}

function Get-PigParseGreenPrice {
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory=$true)][string]$ItemName)
    # Try 'getall' bulk first for speed/reliability
    $all = Get-PigParseGreenAllItems
    if ($all) {
        $hit = $all | Where-Object { $_.n -and ($_.n -match [Regex]::Escape($ItemName)) } | Select-Object -First 1
        if ($hit) {
            $pp = $hit.a30 ?? $hit.a60 ?? $hit.a90 ?? $hit.ay ?? $hit.a6m
            if ($pp) { return [PSCustomObject]@{ item = $ItemName; price = [decimal]$pp; source = 'pigparse.org (getall)'; server = 'green' } }
        }
    }
    # Try JSON endpoints next
    $json = Get-PigParseGreenPriceJson -ItemName $ItemName
    if ($json) {
        # Heuristic extraction
        $cand = @()
        if ($json.results) { $cand += ($json.results | Where-Object { $_.name -match [Regex]::Escape($ItemName) -or $_.n -match [Regex]::Escape($ItemName) } | Select-Object -First 1) }
        if ($json.items) { $cand += ($json.items | Where-Object { $_.name -match [Regex]::Escape($ItemName) -or $_.n -match [Regex]::Escape($ItemName) } | Select-Object -First 1) }
        if (-not $cand -and ($json -is [System.Collections.IEnumerable])) {
            $cand += ($json | Where-Object { ($_.name -and ($_.name -match [Regex]::Escape($ItemName))) -or ($_.n -and ($_.n -match [Regex]::Escape($ItemName))) } | Select-Object -First 1)
        }
        $p = $null
        foreach ($c in $cand) {
            # Prefer 30-day average if present, else fallbacks
            $candPrice = $c.a30 ?? $c.a60 ?? $c.a90 ?? $c.ay ?? $c.a6m ?? $c.avg_price ?? $c.average ?? $c.mean ?? $c.price ?? $c.median
            if ($candPrice) { $p = $candPrice; break }
        }
        if ($p) { return [PSCustomObject]@{ item = $ItemName; price = [decimal]$p; source = 'pigparse.org (json)'; server = 'green' } }
    }
    # Fallback to HTML row scrape
    $row = Get-PigParseGreenPriceRowHtml -ItemName $ItemName
    if (-not $row) { return $null }
    $price = Parse-PriceFromRowHtml -RowHtml $row
    if (-not $price) { return $null }
    return [PSCustomObject]@{ item = $ItemName; price = $price; source = 'pigparse.org (html)'; server = 'green' }
}

# Export-ModuleMember removed - script is dot-sourced, not used as module



# EQGT_EC_Gem_Pricer.ps1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# EverQuest Green Characters: Aedonis, Nebuchadnezzarr, and trader Friartuc
# Purpose: Extract gem items from an EQ inventory export and fetch PP (Platinum) price guidance via PigParse
# Description: Parses EQ inventory exports, identifies gems/runes/words/spells (or all items with -AllItems),
#              queries PigParse for Green server prices, generates sell lists with quantities and suggested PP prices.
#              Supports 7-day caching to reduce API calls.
# Version: 2.0
# Release: 2025-11-18
# Usage:
#   .\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
#   .\EQGT_EC_Gem_Pricer.ps1 -InventoryPath "C:\EQEmu\Desaraeus-Inventory.txt" -UsePigParse:$true -IncludeBank

param(
    [string]$CharacterName,
    [string]$InventoryPath,
    [string]$EQEmuPath,
    [switch]$IncludeBank,
    [switch]$AllItems,
    [string]$OutputCsv,
    [string]$OutputMarkdown,
    [switch]$UsePigParse,
    [int]$SearchLimit
)

# ============================================================================
# SECTION: Module Imports
# ============================================================================

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configModuleLoaded = $false
try {
    Import-Module (Join-Path $scriptRoot "EQGT_Config.psm1") -Force -ErrorAction Stop
    $configModuleLoaded = $true
} catch {
    Write-Warning "Could not load EQGT_Config module. Using defaults. Error: $_"
}

# Fallback functions if config module not available
if (-not $configModuleLoaded) {
    function Get-EQGTEQEmuPath { return "C:\EQEmu" }
    function Get-EQGTOutputDirectory { return $scriptRoot }
    function Get-EQGTScriptRoot { return $scriptRoot }
    function Get-EQGTInventoryPath {
        param([string]$CharacterName, [string]$EQEmuPath = "C:\EQEmu")
        return Join-Path $EQEmuPath "$CharacterName-Inventory.txt"
    }
    function Get-EQGTCacheDirectory {
        # Check environment variable first, then default to script root
        $envCacheDir = [Environment]::GetEnvironmentVariable("EQGT_CACHE_DIR", "Process")
        if (-not $envCacheDir) { $envCacheDir = [Environment]::GetEnvironmentVariable("EQGT_CACHE_DIR", "User") }
        if ($envCacheDir -and (Test-Path -LiteralPath $envCacheDir)) {
            return $envCacheDir
        }
        return $scriptRoot
    }
    function Get-EQGTPigParseCachePath {
        $cacheDir = Get-EQGTCacheDirectory
        return Join-Path $cacheDir "EQGT_cache_pigparse_green.json"
    }
    function Get-EQGTPigParseApiUrl {
        # Check environment variable first, then default
        $envApiUrl = [Environment]::GetEnvironmentVariable("EQGT_PIGPARSE_API_URL", "Process")
        if (-not $envApiUrl) { $envApiUrl = [Environment]::GetEnvironmentVariable("EQGT_PIGPARSE_API_URL", "User") }
        if ($envApiUrl) {
            return $envApiUrl
        }
        return "https://www.pigparse.org"
    }
}

# Set defaults for parameters that weren't provided
if (-not $CharacterName) { $CharacterName = "" }
if (-not $InventoryPath) { $InventoryPath = "" }
if (-not $EQEmuPath) { $EQEmuPath = "" }
if (-not $OutputCsv) { $OutputCsv = "" }
if (-not $OutputMarkdown) { $OutputMarkdown = "" }
if (-not $UsePigParse) { $UsePigParse = $true }
if (-not $SearchLimit) { $SearchLimit = 10 }

# ============================================================================
# SECTION: Helper Functions
# ============================================================================

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

# ============================================================================
# SECTION: Built-in Diagnostics & Auto-Fix
# ============================================================================

function Test-EQGTPriceSystem {
    [OutputType([bool])]
    param(
        [switch]$Silent
    )
    
    $issues = @()
    $autoFixed = @()
    
    # 1. Check cache file
    $cachePath = Get-EQGTPigParseCachePath
    if (Test-Path -LiteralPath $cachePath) {
        try {
            $cacheContent = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
            if ($cacheContent.timestamp) {
                $cacheDate = [DateTime]::Parse($cacheContent.timestamp)
                $age = (Get-Date) - $cacheDate
                if ($age.Days -ge 7) {
                    if (-not $Silent) {
                        Write-Info "Cache expired ($($age.Days) days old), will refresh from API..."
                    }
                } elseif ($cacheContent.data) {
                    # Cache is valid
                    return $true
                }
            }
        } catch {
            # Cache corrupted - will be regenerated
            if (-not $Silent) {
                Write-Warn "Cache file corrupted, will regenerate..."
            }
        }
    }
    
    # 2. Check internet connectivity (quick test)
    try {
        $testResponse = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    } catch {
        $issues += "No internet connection detected"
        return $false
    }
    
    # 3. Test API endpoint (with retry)
    $apiUrl = Get-EQGTPigParseApiUrl
    $fullApiUrl = "$apiUrl/api/item/getall/Green"
    
    $maxRetries = 2
    $retryCount = 0
    $apiWorking = $false
    
    while ($retryCount -le $maxRetries -and -not $apiWorking) {
        try {
            if ($retryCount -gt 0 -and -not $Silent) {
                Write-Info "Retrying API connection (attempt $($retryCount + 1)/$($maxRetries + 1))..."
            }
            $response = Invoke-WebRequest -Uri $fullApiUrl -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            if ($response.StatusCode -eq 200 -and $response.Content) {
                try {
                    $testJson = $response.Content | ConvertFrom-Json
                    if ($testJson -is [Array] -and $testJson.Count -gt 0) {
                        $apiWorking = $true
                        if ($retryCount -gt 0 -and -not $Silent) {
                            Write-Ok "API connection successful after retry"
                        }
                    }
                } catch {
                    # JSON parse failed
                }
            }
        } catch {
            $retryCount++
            if ($retryCount -gt $maxRetries) {
                $errorMsg = $_.Exception.Message
                if ($errorMsg -match "timeout") {
                    $issues += "API timeout - server may be slow. Try again in a few minutes."
                } elseif ($errorMsg -match "SSL|certificate") {
                    $issues += "SSL/certificate error - check system date/time"
                } elseif ($errorMsg -match "forbidden|403") {
                    $issues += "API access forbidden - may be blocking requests"
                } elseif ($errorMsg -match "not found|404") {
                    $issues += "API endpoint not found - endpoint may have changed"
                } else {
                    $issues += "API connection failed: $errorMsg"
                }
            }
        }
    }
    
    if ($apiWorking) {
        return $true
    }
    
    # 4. Check PowerShell cmdlets
    $required = @('ConvertFrom-Json', 'ConvertTo-Json', 'Invoke-WebRequest')
    foreach ($cmdlet in $required) {
        if (-not (Get-Command $cmdlet -ErrorAction SilentlyContinue)) {
            $issues += "Missing PowerShell cmdlet: $cmdlet"
        }
    }
    
    # 5. Check cache directory write permissions
    $cacheDir = Split-Path -Parent $cachePath
    if (-not (Test-Path -LiteralPath $cacheDir)) {
        try {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            $autoFixed += "Created cache directory"
        } catch {
            $issues += "Cannot create cache directory: $cacheDir"
        }
    } else {
        try {
            $testFile = Join-Path $cacheDir "EQGT_test_write.tmp"
            "test" | Set-Content -LiteralPath $testFile -ErrorAction Stop
            Remove-Item -LiteralPath $testFile -ErrorAction SilentlyContinue
        } catch {
            $issues += "No write permission to cache directory: $cacheDir"
        }
    }
    
    # Report results
    if ($issues.Count -eq 0) {
        return $true
    }
    
    if (-not $Silent) {
        Write-Warn "`n⚠ Price system diagnostics found issues:"
        foreach ($issue in $issues) {
            Write-Warn "  • $issue"
        }
        if ($autoFixed.Count -gt 0) {
            Write-Ok "`n✓ Auto-fixed:"
            foreach ($fix in $autoFixed) {
                Write-Ok "  • $fix"
            }
        }
        Write-Warn "`nAll prices will show as TBD until issues are resolved."
        Write-Warn "Run EQGT_Diagnose_Pricing.ps1 for detailed diagnostics.`n"
    }
    
    return $false
}

# ============================================================================
# SECTION: File & Data Validation
# ============================================================================

function Assert-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Input file not found: $Path"
    }
}

# ============================================================================
# SECTION: Item Extraction Functions
# ============================================================================

function Get-GemCandidates {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)] [string]$InventoryCsvPath,
        [switch]$IncludeBankSlots
    )
    Assert-File -Path $InventoryCsvPath
    $rows = Get-Content -LiteralPath $InventoryCsvPath | ConvertFrom-Csv -Delimiter "`t"

    $slotPattern = if ($IncludeBankSlots) {
        '^(General\d+-Slot\d+|Bank\d+-Slot\d+)$'
    } else {
        '^General\d+-Slot\d+$'
    }

    $gemNameHints = @(
        'Flawed Flame Opal','Flawed Topaz','Flawed Opal','Flame Opal','Topaz','Opal',
        'Black Pearl','Pearl','Onyx','Nephrite','Jaundice Gem','Black Marble','Chipped Black Marble',
        'Crushed Black Marble','Crushed Jaundice Gem','Crushed Chrysolite','Crushed Opal','Crushed Lava Ruby',
        'Chrysolite','Lava Ruby','Emerald','Sapphire','Diamond','Fire Emerald','Peridot',
        'Aquamarine','Amethyst','Garnet','Star Ruby','A Scarlet Stone','Velium'
    )

    $gems = @{}
    foreach ($r in $rows) {
        if (-not ($r.Location -match $slotPattern)) { continue }
        $name = [string]$r.Name
        if (-not $name -or $name -eq 'Empty') { continue }
        $isGem = $false
        foreach ($hint in $gemNameHints) {
            if ($name -match [Regex]::Escape($hint)) { $isGem = $true; break }
        }
        if (-not $isGem) { continue }
        $count = 1
        if ($r.PSObject.Properties.Name -contains 'Count') {
            [int]$count = if ([int]::TryParse($r.Count, [ref]0)) { [int]$r.Count } else { 1 }
        }
        if ($gems.ContainsKey($name)) { $gems[$name] += $count } else { $gems[$name] = $count }
    }
    return $gems
}

function Get-ItemsByRegex {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)] [string]$InventoryCsvPath,
        [Parameter(Mandatory=$true)] [string]$NameRegex,
        [switch]$IncludeBankSlots
    )
    Assert-File -Path $InventoryCsvPath
    $rows = Get-Content -LiteralPath $InventoryCsvPath | ConvertFrom-Csv -Delimiter "`t"

    $slotPattern = if ($IncludeBankSlots) {
        '^(General\d+-Slot\d+|Bank\d+-Slot\d+)$'
    } else {
        '^General\d+-Slot\d+$'
    }

    $items = @{}
    foreach ($r in $rows) {
        if (-not ($r.Location -match $slotPattern)) { continue }
        $name = [string]$r.Name
        if (-not $name -or $name -eq 'Empty') { continue }
        if (-not ($name -match $NameRegex)) { continue }
        $count = 1
        if ($r.PSObject.Properties.Name -contains 'Count') {
            [int]$count = if ([int]::TryParse($r.Count, [ref]0)) { [int]$r.Count } else { 1 }
        }
        if ($items.ContainsKey($name)) { $items[$name] += $count } else { $items[$name] = $count }
    }
    return $items
}

function Get-AllBagItems {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)] [string]$InventoryCsvPath,
        [switch]$IncludeBankSlots
    )
    Assert-File -Path $InventoryCsvPath
    $rows = Get-Content -LiteralPath $InventoryCsvPath | ConvertFrom-Csv -Delimiter "`t"

    $slotPattern = if ($IncludeBankSlots) {
        '^(General\d+-Slot\d+|Bank\d+-Slot\d+)$'
    } else {
        '^General\d+-Slot\d+$'
    }

    $items = @{}
    foreach ($r in $rows) {
        if (-not ($r.Location -match $slotPattern)) { continue }
        $name = [string]$r.Name
        if (-not $name -or $name -eq 'Empty') { continue }
        
        $count = 1
        if ($r.PSObject.Properties.Name -contains 'Count') {
            [int]$count = if ([int]::TryParse($r.Count, [ref]0)) { [int]$r.Count } else { 1 }
        }
        
        if ($items.ContainsKey($name)) {
            $items[$name] += $count
        } else {
            $items[$name] = $count
        }
    }
    return $items
}

# ============================================================================
# SECTION: Price Lookup Functions
# ============================================================================

function Get-GemPriceGuidance {
    [OutputType([object[]])]
    param(
        [hashtable]$GemCounts,
        [switch]$UseApi,
        [int]$Limit = 10,
        [string]$CategoryName = "",
        [switch]$ShowProgress
    )
    $results = @()
    $totalItems = $GemCounts.Count
    $currentItem = 0
    
    # Load the bulk price list once (uses 7-day cache)
    $bulkPriceList = $null
    if ($UseApi) {
        $scriptRoot = Get-EQGTScriptRoot
        $scraper = Join-Path $scriptRoot 'EQGT_PigParse_Scraper.ps1'
        if (Test-Path -LiteralPath $scraper) {
            try { 
                # Dot-source the scraper, but ignore Export-ModuleMember errors
                $ErrorActionPreference = 'SilentlyContinue'
                . $scraper 2>$null
                $ErrorActionPreference = 'Continue'
                
                # Run built-in diagnostics (silent if everything OK)
                $systemOk = Test-EQGTPriceSystem -Silent
                
                # Check if cache exists to give appropriate message
                $cachePath = Get-EQGTPigParseCachePath
                if (Test-Path -LiteralPath $cachePath) {
                    Write-Info 'Loading price list from cache (7 day cache)...'
                } else {
                    Write-Info 'Loading price list (no cache found - will download from API)...'
                }
                
                $bulkPriceList = Get-PigParseGreenAllItems
                if ($bulkPriceList) {
                    Write-Ok "Loaded price list with $($bulkPriceList.Count) items from cache/API"
                } else {
                    # Only show detailed warnings if system check found issues
                    if (-not $systemOk) {
                        Write-Warn "Could not load bulk price list - all prices will show as TBD"
                        Write-Warn "Run EQGT_Diagnose_Pricing.ps1 for detailed diagnostics."
                    } else {
                        # System check passed but still failed - likely transient issue
                        Write-Warn "Could not load bulk price list (API may be temporarily unavailable)"
                        Write-Warn "Prices will show as TBD. Try again in a few minutes."
                    }
                }
            } catch {
                Write-Warn "Failed to load price scraper: $_"
            }
        }
    }
    
    foreach ($name in ($GemCounts.Keys | Sort-Object)) {
        $currentItem++
        $qty = [int]$GemCounts[$name]
        $price = $null
        
        if ($ShowProgress) {
            Write-Info "[$currentItem/$totalItems] Looking up: $name (Qty: $qty)"
        }
        
        if ($UseApi -and $bulkPriceList) {
            # Use bulk price list - no individual API calls!
            $hit = $bulkPriceList | Where-Object { 
                $itemName = $_.n ?? $_.name ?? ""
                $itemName -match [Regex]::Escape($name) 
            } | Select-Object -First 1
            
            if ($hit) {
                # Prefer 30-day average, fallback to other averages
                $price = $hit.a30 ?? $hit.a60 ?? $hit.a90 ?? $hit.ay ?? $hit.a6m ?? $hit.avg_price ?? $hit.average ?? $hit.mean ?? $hit.price ?? $hit.median
                if ($price) {
                    $price = [decimal]$price
                    if ($ShowProgress) {
                        Write-Ok "  Found price: $price PP (from bulk list)"
                    }
                }
            } else {
                if ($ShowProgress) {
                    Write-Warn "  No price found in bulk list"
                }
            }
        }
        
        $total = if ($price) { [decimal]$price * $qty } else { $null }
        $results += [PSCustomObject]@{
            Item   = $name
            Qty    = $qty
            Price  = $price
            Total  = $total
            Category = $CategoryName
        }
    }
    return $results | Sort-Object Item
}

# ============================================================================
# SECTION: Output Generation
# ============================================================================

function Write-Outputs {
    param([object[]]$Rows, [string]$CsvPath, [string]$MdPath, [string]$CharacterName = "")
    function Sanitize-ForMarkdown {
        param([string]$Text)
        if (-not $Text) { return $Text }
        $t = $Text -replace '\|', '\\|'   # escape pipe
        $t = $t -replace '`', '\\`'        # escape backtick
        return $t
    }
    if ($Rows -and $Rows.Count -gt 0) {
        $Rows | Export-Csv -NoTypeInformation -LiteralPath $CsvPath -Encoding UTF8
        $md = @()
        
        $title = if ($CharacterName) {
            "# $CharacterName - Inventory Pricing Report"
        } else {
            "# Inventory Pricing Report"
        }
        $md += $title
        $md += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $md += ""
        
        $hasCategory = $Rows[0].PSObject.Properties.Name -contains 'Category'
        if ($hasCategory) {
            $md += '| Category | Item | Qty | Price (PP) | Total (PP) |'
            $md += '|---|---|---:|---:|---:|'
        } else {
            $md += '| Item | Qty | Price (PP) | Total (PP) |'
            $md += '|---|---:|---:|---:|'
        }
        
        $grandTotal = 0
        $itemsWithPrice = 0
        $itemsWithoutPrice = 0
        
        foreach ($r in $Rows) {
            $p = if ($r.Price) { ('{0:N0}' -f [decimal]$r.Price) } else { 'TBD' }
            $t = if ($r.Total) { 
                $grandTotal += [decimal]$r.Total
                $itemsWithPrice++
                ('{0:N0}' -f [decimal]$r.Total) 
            } else { 
                $itemsWithoutPrice++
                'TBD' 
            }
            $cat = if ($hasCategory) { Sanitize-ForMarkdown $r.Category } else { $null }
            $name = Sanitize-ForMarkdown $r.Item
            if ($hasCategory) {
                $line = ('| {0} | {1} | {2} | {3} | {4} |' -f $cat, $name, $r.Qty, $p, $t)
                $md += $line
            } else {
                $line = ('| {0} | {1} | {2} | {3} |' -f $name, $r.Qty, $p, $t)
                $md += $line
            }
        }
        
        $md += ""
        $md += "## Summary"
        $md += "- Total Items: $($Rows.Count)"
        $md += "- Items with Prices: $itemsWithPrice"
        $md += "- Items without Prices: $itemsWithoutPrice"
        if ($grandTotal -gt 0) {
            $md += "- **Grand Total: {0:N0} PP**" -f $grandTotal
        }
        
        $md -join [Environment]::NewLine | Set-Content -LiteralPath $MdPath -Encoding UTF8
        Write-Ok "Saved CSV: $CsvPath"
        Write-Ok "Saved Markdown: $MdPath"
        if ($grandTotal -gt 0) {
            Write-Ok "Grand Total: {0:N0} PP" -f $grandTotal
        }
    } else {
        Write-Warn "No rows to write."
    }
}

# ============================================================================
# SECTION: Main Execution
# ============================================================================

try {
    # Get EQEmu path from config (with auto-detection) if not provided
    if (-not $EQEmuPath) {
        $EQEmuPath = Get-EQGTEQEmuPath
    }
    
    # Get output directory from config
    $outputDir = Get-EQGTOutputDirectory
    
    # Determine inventory path
    if ($CharacterName -and $CharacterName -ne "") {
        $InventoryPath = Get-EQGTInventoryPath -CharacterName $CharacterName -EQEmuPath $EQEmuPath
        if (-not $OutputCsv) {
            $OutputCsv = Join-Path $outputDir "EQGT_${CharacterName}_Pricing.csv"
        }
        if (-not $OutputMarkdown) {
            $OutputMarkdown = Join-Path $outputDir "EQGT_${CharacterName}_Pricing.md"
        }
    } elseif (-not $InventoryPath -or $InventoryPath -eq "") {
        Write-Error "Either -CharacterName or -InventoryPath must be provided"
        exit 1
    }
    
        if (-not $OutputCsv) {
            $OutputCsv = Join-Path $outputDir "EQGT_EC_Sell_List.csv"
        }
        if (-not $OutputMarkdown) {
            $OutputMarkdown = Join-Path $outputDir "EQGT_EC_Sell_List.md"
        }
    
    Write-Info "Reading inventory: $InventoryPath"
    
    if ($AllItems) {
        # Price ALL items in bags
        $allItemCounts = Get-AllBagItems -InventoryCsvPath $InventoryPath -IncludeBankSlots:$IncludeBank
        Write-Ok ("Found {0} unique item types in bags" -f $allItemCounts.Count)
        Write-Ok ("Total item count: {0}" -f ($allItemCounts.Values | Measure-Object -Sum).Sum)
        
        Write-Info "`nPricing all items via PigParse..."
        $allRows = Get-GemPriceGuidance -GemCounts $allItemCounts -UseApi:$UsePigParse -Limit $SearchLimit -ShowProgress
        
        Write-Info "`n=== Pricing Results ==="
        $allRows | Format-Table -AutoSize | Out-Host
        
        Write-Outputs -Rows $allRows -CsvPath $OutputCsv -MdPath $OutputMarkdown -CharacterName $CharacterName
    } else {
        # Original behavior: price gems/runes/words/spells only
        $gemCounts = Get-GemCandidates -InventoryCsvPath $InventoryPath -IncludeBankSlots:$IncludeBank
        Write-Ok ("Found {0} gem types" -f $gemCounts.Count)

        $runeCounts  = Get-ItemsByRegex -InventoryCsvPath $InventoryPath -NameRegex '^Rune\b' -IncludeBankSlots:$IncludeBank
        $wordCounts  = Get-ItemsByRegex -InventoryCsvPath $InventoryPath -NameRegex '^Words\b' -IncludeBankSlots:$IncludeBank
        $spellCounts = Get-ItemsByRegex -InventoryCsvPath $InventoryPath -NameRegex '^Spell:' -IncludeBankSlots:$IncludeBank

        $rowsG = Get-GemPriceGuidance -GemCounts $gemCounts -UseApi:$UsePigParse -Limit $SearchLimit -CategoryName 'Gem'
        $rowsR = Get-GemPriceGuidance -GemCounts $runeCounts -UseApi:$UsePigParse -Limit $SearchLimit -CategoryName 'Rune'
        $rowsW = Get-GemPriceGuidance -GemCounts $wordCounts -UseApi:$UsePigParse -Limit $SearchLimit -CategoryName 'Words'
        $rowsS = Get-GemPriceGuidance -GemCounts $spellCounts -UseApi:$UsePigParse -Limit $SearchLimit -CategoryName 'Spell'

        Write-Info "Gems"
        $rowsG | Format-Table -AutoSize | Out-Host
        Write-Info "Runes"
        $rowsR | Format-Table -AutoSize | Out-Host
        Write-Info "Words"
        $rowsW | Format-Table -AutoSize | Out-Host
        Write-Info "Spells"
        $rowsS | Format-Table -AutoSize | Out-Host

        $all = @(); $all += $rowsG; $all += $rowsR; $all += $rowsW; $all += $rowsS
        Write-Outputs -Rows $all -CsvPath $OutputCsv -MdPath $OutputMarkdown -CharacterName $CharacterName
    }
}
catch {
    Write-Error $_
    throw
}



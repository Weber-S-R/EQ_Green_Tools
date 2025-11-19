# EQGT_Character_Inventory_Analyzer.ps1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# EverQuest Green Characters: Aedonis, Nebuchadnezzarr, and trader Friartuc
# Purpose: Analyzes all character inventories on Green server for sellable items
# Description: Scans all character inventory exports, categorizes items (gems, runes, words, spells, research pages),
#              identifies sellable items and generates summary reports
# Version: 2.0
# Release: 2025-11-18
# Usage:
#   .\EQGT_Character_Inventory_Analyzer.ps1

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
    function Get-EQGTCharacterList {
        return @('Nebuchadnezzarr', 'Aedonis', 'Desaraeus', 'Prismatix', 'Badscot', 'Bigmasher', 
                 'Birchwood', 'Bruceknee', 'Bukobgar', 'Crushermoosher', 'Entomb', 'Friartuc', 
                 'Gnomine', 'Highburn', 'Mukbut', 'Nautemili', 'Trueoak')
    }
}

param(
    [string]$EQEmuPath = "",
    [string]$OutputFile = ""
)

# ============================================================================
# SECTION: Helper Functions
# ============================================================================

function Write-Section { param([string]$s) Write-Host "`n=== $s ===" -ForegroundColor Cyan }

# ============================================================================
# SECTION: Data Extraction Functions
# ============================================================================

function Get-NonWornItems {
    param([string]$InvPath)
    if (-not (Test-Path $InvPath)) { return @() }
    $rows = Get-Content $InvPath | ConvertFrom-Csv -Delimiter "`t"
    return $rows | Where-Object { 
        $_.Location -match '^(General\d+-Slot\d+|Bank\d+-Slot\d+|SharedBank\d+-Slot\d+)$' -and
        $_.Name -and $_.Name -ne 'Empty'
    }
}

function Categorize-Item {
    param([string]$Name)
    $n = [string]$Name
    if ($n -match '^Spell:') { return 'Spell' }
    if ($n -match '^Rune\b') { return 'Rune' }
    if ($n -match '^Words\b') { return 'Words' }
    if ($n -match 'Grimoire|Writ|Tome') { return 'ResearchPage' }
    if ($n -match 'Pearl|Opal|Topaz|Emerald|Sapphire|Ruby|Diamond|Amber|Jade|Jasper|Onyx|Peridot|Aquamarine|Garnet|Amethyst|Velium|Marble|Chrysolite|Nephrite|Jaundice|Flawed|Crushed|Chipped|Black Pearl|Fire Emerald|Star Ruby|Flame Opal') { return 'Gem' }
    if ($n -match 'Backpack|Pack|Bag|Box') { return 'Container' }
    if ($n -match 'Ration|Wine|Water|Mead|Elven') { return 'FoodDrink' }
    if ($n -match 'Arrow|Arrowhead|Fletching|Nock|Shaft') { return 'AmmoComponent' }
    if ($n -match 'Silk|Hide|Skin|F mat|Fur|Leather') { return 'TradeMaterial' }
    return 'Other'
}

# ============================================================================
# SECTION: Main Configuration
# ============================================================================

# Get EQEmu path from config (with auto-detection) if not provided
if (-not $EQEmuPath) {
    $EQEmuPath = Get-EQGTEQEmuPath
}

# Get output directory from config if output file not specified
if (-not $OutputFile) {
    $outputDir = Get-EQGTOutputDirectory
    $OutputFile = Join-Path $outputDir "EQGT_Character_Inventory_Summary.txt"
}

# Get character list from config
$allChars = Get-EQGTCharacterList

# ============================================================================
# SECTION: Report Generation
# ============================================================================

$report = @()
$report += "EQGT Character Inventory Summary - Green Server"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "=" * 80

# ============================================================================
# SECTION: Character Processing Loop
# ============================================================================

foreach ($char in $allChars) {
    $invPath = Join-Path $EQEmuPath "$char-Inventory.txt"
    if (-not (Test-Path $invPath)) {
        $report += "`n[$char] - NO INVENTORY FILE (run /output inventory in-game)"
        continue
    }
    
    Write-Section "Analyzing $char"
    $items = Get-NonWornItems -InvPath $invPath
    if ($items.Count -eq 0) {
        $report += "`n[$char] chambers are empty."
        continue
    }
    
    $cats = @{}
    $byCat = @{}
    foreach ($item in $items) {
        $cat = Categorize-Item -Name $item.Name
        if (-not $byCat.ContainsKey($cat)) { $byCat[$cat] = @{} }
        $name = $item.Name
        $qty = if ([int]::TryParse($item.Count, [ref]0)) { [int]$item.Count } else { 1 }
        if ($byCat[$cat].ContainsKey($name)) {
            $byCat[$cat][$name] += $qty
        } else {
            $byCat[$cat][$name] = $qty
        }
    }
    
    $report += "`n[$char]"
    $report += "-" * 60
    $report += "Total Non-Worn Items: $($items.Count)"
    
    foreach ($cat in ($byCat.Keys | Sort-Object)) {
        $count = ($byCat[$cat].Values | Measure-Object -Sum).Sum
        $report += "  $cat : $count items"
    }
    
    # Flag potentially valuable categories
    $valuableCats = @('Spell', 'Rune', 'Words', 'ResearchPage', 'Gem')
    $hasValuable = $valuableCats | Where-Object { $byCat.ContainsKey($_) }
    if ($hasValuable) {
        $report += "  *** SELLABLE: $($hasValuable -join ', ') ***"
        foreach ($vc in $hasValuable) {
            foreach ($name in ($byCat[$vc].Keys | Sort-Object)) {
                $qty = $byCat[$vc][$name]
                $report += "    - $name x$qty"
            }
        }
    }
}

$report | Out-File -FilePath $OutputFile -Encoding UTF8
$report | Out-Host

Write-Host "`nReport saved to: $OutputFile" -ForegroundColor Green


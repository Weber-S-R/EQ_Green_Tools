# EQGT_Inventory_Table_Viewer.ps1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# EverQuest Green Characters: Aedonis, Nebuchadnezzarr, and trader Friartuc
# Purpose: Cross-character inventory table viewer - search items across all characters
# Description: Generates cross-character tables showing item quantities by character
#              Supports searching for any item type (Runes, Words, Spells, Gems, etc.)
# Version: 2.0
# Release: 2025-11-18
# Usage: 
#   .\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune"
#   .\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Words" -ShowEmpty

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
        return @('Nebuchadnezzarr', 'Aedonis', 'Desaraeus', 'Prismatix', 'Mukbut', 'Trueoak', 
                 'Badscot', 'Bigmasher', 'Birchwood', 'Bruceknee', 'Bukobgar', 'Crushermoosher', 
                 'Entomb', 'Friartuc', 'Gnomine', 'Highburn', 'Nautemili')
    }
}

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$ItemSearch = "",
    
    [string]$EQEmuPath = "",
    [string]$OutputFile = "",
    [switch]$ShowEmpty
)

# For gems table, we use Is-Gem function instead of ItemSearch
# If ItemSearch is provided, use it; otherwise search for gems
$useGemSearch = (-not $ItemSearch)

# ============================================================================
# SECTION: Helper Functions
# ============================================================================

function Write-Section { param([string]$s) Write-Host "`n=== $s ===" -ForegroundColor Cyan }

function Is-Gem {
    param([string]$Name)
    $n = [string]$Name
    if ($n -match 'Pearl|Opal|Topaz|Emerald|Sapphire|Ruby|Diamond|Amber|Jade|Jasper|Onyx|Peridot|Aquamarine|Garnet|Amethyst|Velium|Marble|Chrysolite|Nephrite|Jaundice|Flawed|Crushed|Chipped|Black Pearl|Fire Emerald|Star Ruby|Flame Opal|Scarlet Stone') {
        return $true
    }
    return $false
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
    $OutputFile = Join-Path $outputDir "EQGT_Equipped_Gems_Table.txt"
}

# Get character list from config
$allChars = Get-EQGTCharacterList

# Filter for characters played in last 7 days (based on inventory file modification date)
$sevenDaysAgo = (Get-Date).AddDays(-7)
$activeChars = @()
foreach ($c in $allChars) {
    $f = Join-Path $EQEmuPath "$c-Inventory.txt"
    if ((Test-Path $f) -and (Get-Item $f).LastWriteTime -ge $sevenDaysAgo) {
        $activeChars += $c
    }
}

Write-Host "Found $($activeChars.Count) characters played in last 7 days: $($activeChars -join ', ')" -ForegroundColor Cyan

# ============================================================================
# SECTION: Data Collection
# ============================================================================

$allItems = @{}
$charsWithData = @()

foreach ($c in $activeChars) {
    $f = Join-Path $EQEmuPath "$c-Inventory.txt"
    if (-not (Test-Path $f)) { continue }
    
    try {
        $rows = Get-Content $f | ConvertFrom-Csv -Delimiter "`t"
        # Filter items based on location and name
        $items = $rows | Where-Object { 
            $isValidLocation = $_.Location -match '^(General\d+-Slot\d+|Bank\d+-Slot\d+|SharedBank\d+-Slot\d+|Charm|Ear|Head|Face|Neck|Shoulders|Arms|Back|Wrist|Range|Hands|Primary|Secondary|Fingers|Chest|Legs|Feet|Waist)$'
            $hasName = $_.Name -and $_.Name -ne 'Empty'
            if (-not ($isValidLocation -and $hasName)) { return $false }
            
            if ($useGemSearch) {
                return (Is-Gem $_.Name)
            } else {
                return ($_.Name -match $ItemSearch)
            }
        }
        
        if ($items.Count -gt 0) {
            $charsWithData += $c
            foreach ($item in $items) {
                $name = $item.Name
                $qty = if ([int]::TryParse($item.Count, [ref]0)) { [int]$item.Count } else { 1 }
                
                if (-not $allItems.ContainsKey($name)) {
                    $allItems[$name] = @{}
                }
                
                if ($allItems[$name].ContainsKey($c)) {
                    $allItems[$name][$c] += $qty
                } else {
                    $allItems[$name][$c] = $qty
                }
            }
        }
    } catch {
        Write-Warning "Error reading $c : $_"
    }
}

if ($allItems.Count -eq 0) {
    Write-Host "No gems found across any characters played in last 7 days." -ForegroundColor Yellow
    exit
}

# ============================================================================
# SECTION: Table Generation
# ============================================================================

$tableChars = if ($ShowEmpty) { $activeChars | Sort-Object } else { $charsWithData | Sort-Object | Get-Unique }

# Calculate column widths for better readability
$colWidths = @{}
$colWidths['Gem'] = 42  # Gem name column
foreach ($c in $tableChars) {
    # Make number columns wider for readability
    $colWidths[$c] = [Math]::Max($c.Length + 3, 12)
}

# Update gem column width based on actual data
$maxGemWidth = ($allItems.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
if ($maxGemWidth) { $colWidths['Gem'] = [Math]::Max($colWidths['Gem'], $maxGemWidth + 2) }

$table = @()

# Create separator line using simple ASCII
function New-SeparatorLine {
    $line = "+" + ("-" * ($colWidths['Gem'] + 2))
    foreach ($c in $tableChars) {
        $line += "+" + ("-" * ($colWidths[$c] + 2))
    }
    $line += "+"
    return $line
}

# Format row with proper alignment
function Format-Row {
    param([string[]]$Values, [switch]$IsHeader)
    $row = "|"
    # First column (Gem name) - left aligned with padding
    $gemVal = $Values[0]
    $row += " " + ($gemVal.PadRight($colWidths['Gem'])) + " |"
    # Remaining columns (numbers) - right aligned for readability
    for ($i = 1; $i -lt $Values.Length; $i++) {
        $val = if ($Values[$i]) { $Values[$i].ToString() } else { " " }
        $charName = $tableChars[$i-1]
        if ($IsHeader) {
            # Header is left-aligned
            $row += " " + ($val.PadRight($colWidths[$charName])) + " |"
        } else {
            # Numbers are right-aligned
            $row += " " + ($val.PadLeft($colWidths[$charName])) + " |"
        }
    }
    return $row
}

# Build table with clean borders - each cell completely contained
$table += New-SeparatorLine
$headerRow = @("Gem") + ($tableChars | ForEach-Object { $_ })
$table += Format-Row -Values $headerRow -IsHeader
$table += New-SeparatorLine

foreach ($itemName in ($allItems.Keys | Sort-Object)) {
    $rowValues = @($itemName)
    foreach ($c in $tableChars) {
        $val = if ($allItems[$itemName].ContainsKey($c)) { $allItems[$itemName][$c].ToString() } else { "" }
        $rowValues += $val
    }
    # Only add line if it has data (when ShowEmpty is false) or always (when ShowEmpty is true)
    $hasData = $rowValues[1..($rowValues.Length-1)] | Where-Object { $_ -ne "" }
    if ($ShowEmpty -or $hasData) {
        $table += Format-Row -Values $rowValues
        $table += New-SeparatorLine  # Add separator after each row to fully contain each cell
    }
}

# ============================================================================
# SECTION: Output
# ============================================================================

Write-Section "Equipped Gems by Character (Last 7 Days)"
$table | Out-Host

# Output file already set in configuration section above

$table | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "`nTable saved to: $OutputFile" -ForegroundColor Green


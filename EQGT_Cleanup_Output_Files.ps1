# EQGT_Cleanup_Output_Files.ps1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# Purpose: Clean up old generated output files (CSV, MD, TXT, MMD)
# Description: Removes old pricing reports, inventory summaries, and table files
#              to prevent directory clutter. Preserves cache, config, and script files.
# Version: 2.0
# Release: 2025-01-XX
# Usage:
#   .\EQGT_Cleanup_Output_Files.ps1                    # Remove all output files
#   .\EQGT_Cleanup_Output_Files.ps1 -KeepDays 7        # Keep files newer than 7 days
#   .\EQGT_Cleanup_Output_Files.ps1 -KeepRecent 5       # Keep 5 most recent of each type
#   .\EQGT_Cleanup_Output_Files.ps1 -WhatIf            # Preview what would be deleted

param(
    [int]$KeepDays = 0,           # Keep files newer than X days (0 = delete all)
    [int]$KeepRecent = 0,          # Keep X most recent files of each type (0 = delete all)
    [switch]$WhatIf,              # Preview mode - don't actually delete
    [switch]$IncludeCache,         # Also delete cache file (default: preserve cache)
    [switch]$Force                # Skip confirmation prompt
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Info { param([string]$m) Write-Host $m -ForegroundColor Cyan }
function Write-Ok { param([string]$m) Write-Host $m -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host $m -ForegroundColor Yellow }
function Write-Error { param([string]$m) Write-Host $m -ForegroundColor Red }

# Output file patterns to clean
$outputPatterns = @(
    "EQGT_*_Pricing.csv",
    "EQGT_*_Pricing.md",
    "EQGT_EC_Sell_List.csv",
    "EQGT_EC_Sell_List.md",
    "EQGT_Character_Inventory_Summary.txt",
    "EQGT_Equipped_Gems_Table.txt",
    "EQGT_Equipped_Gems_Table.mmd",
    "EQGT_Equipped_Gems_Table_Detailed.mmd"
)

# Files to NEVER delete (protected patterns)
# Note: Inventory files (*-Inventory.txt) are in EQEmu directory, not script directory,
# so they're already safe, but we protect them here as an extra safety measure
$protectedPatterns = @(
    "EQGT_*.ps1",          # All PowerShell scripts
    "EQGT_*.psm1",         # All PowerShell modules
    "EQGT_README.md",      # Main documentation
    "EQGT_Configuration_Guide.md",
    "EQGT_DEPENDENCIES.md",
    "EQGT_Dependency_Check.md",
    "EQGT_V3.0_Release_Updates.md",
    "EQGT_pigparse_config.json",  # Config file
    "EQGT_cache_pigparse_green.json",  # Cache (unless IncludeCache)
    "EQ_Green_Tools_*.zip", # Archives
    "*-Inventory.txt"      # Character inventory files (game-generated, always overwritten by /output inventory)
)

Write-Info "`n=== EQGT Output File Cleanup ==="
Write-Info ""

if ($WhatIf) {
    Write-Warn "PREVIEW MODE - No files will be deleted"
    Write-Info ""
}

# Collect all output files
$filesToDelete = @()
$filesToKeep = @()

foreach ($pattern in $outputPatterns) {
    $files = Get-ChildItem -Path $scriptRoot -Filter $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        # Check if file is protected
        $isProtected = $false
        foreach ($protectedPattern in $protectedPatterns) {
            if ($file.Name -like $protectedPattern) {
                $isProtected = $true
                break
            }
        }
        
        # Skip protected files
        if ($isProtected) {
            continue
        }
        
        # Additional protection: Never delete inventory .txt files (even if they match a pattern)
        if ($file.Name -match '-Inventory\.txt$') {
            continue
        }
        
        $age = (Get-Date) - $file.LastWriteTime
        
        # Check if file should be kept based on age
        $keepByAge = $false
        if ($KeepDays -gt 0) {
            if ($age.Days -lt $KeepDays) {
                $keepByAge = $true
                $filesToKeep += $file
            }
        }
        
        # If not kept by age, add to delete list
        if (-not $keepByAge) {
            $filesToDelete += $file
        }
    }
}

# If KeepRecent is specified, keep the most recent files of each type
if ($KeepRecent -gt 0) {
    $filesToDelete = @()
    $filesToKeep = @()
    
    # Group files by type (base name pattern)
    $fileGroups = @{}
    foreach ($pattern in $outputPatterns) {
        $files = Get-ChildItem -Path $scriptRoot -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            # Check if file is protected
            $isProtected = $false
            foreach ($protectedPattern in $protectedPatterns) {
                if ($file.Name -like $protectedPattern) {
                    $isProtected = $true
                    break
                }
            }
            
            # Skip protected files
            if ($isProtected) {
                continue
            }
            
            # Additional protection: Never delete inventory .txt files
            if ($file.Name -match '-Inventory\.txt$') {
                continue
            }
            
            # Extract base pattern (e.g., "EQGT_*_Pricing" from "EQGT_*_Pricing.csv")
            $basePattern = $pattern -replace '\.[^.]+$', ''
            if (-not $fileGroups.ContainsKey($basePattern)) {
                $fileGroups[$basePattern] = @()
            }
            $fileGroups[$basePattern] += $file
        }
    }
    
    # For each group, keep most recent N files
    foreach ($group in $fileGroups.Keys) {
        $files = $fileGroups[$group] | Sort-Object LastWriteTime -Descending
        $keep = $files | Select-Object -First $KeepRecent
        $delete = $files | Select-Object -Skip $KeepRecent
        
        $filesToKeep += $keep
        $filesToDelete += $delete
    }
}

# Handle cache file if IncludeCache is specified
if ($IncludeCache) {
    $cacheFile = Join-Path $scriptRoot "EQGT_cache_pigparse_green.json"
    if (Test-Path -LiteralPath $cacheFile) {
        $filesToDelete += Get-Item -LiteralPath $cacheFile
        Write-Warn "Cache file will be deleted (will be regenerated on next run)"
    }
}

# Display summary
Write-Info "Files to keep: $($filesToKeep.Count)"
if ($filesToKeep.Count -gt 0) {
    foreach ($file in $filesToKeep) {
        $age = (Get-Date) - $file.LastWriteTime
        Write-Info "  KEEP: $($file.Name) ($($age.Days) days old)"
    }
}

Write-Info ""
Write-Info "Files to delete: $($filesToDelete.Count)"

if ($filesToDelete.Count -eq 0) {
    Write-Ok "No files to clean up!"
    exit 0
}

# Show what will be deleted
$totalSize = 0
foreach ($file in $filesToDelete) {
    $age = (Get-Date) - $file.LastWriteTime
    $size = $file.Length
    $totalSize += $size
    $sizeMB = [math]::Round($size / 1MB, 2)
    Write-Warn "  DELETE: $($file.Name) ($($age.Days) days old, $sizeMB MB)"
}

$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
Write-Info ""
Write-Info "Total space to free: $totalSizeMB MB"

# Confirm deletion (skip if -Force is used)
if (-not $WhatIf) {
    if (-not $Force) {
        Write-Info ""
        $confirm = Read-Host "Delete these $($filesToDelete.Count) file(s)? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Info "Cleanup cancelled."
            exit 0
        }
    } else {
        Write-Info ""
        Write-Info "Force mode: Skipping confirmation..."
    }
    
    # Delete files
    $deleted = 0
    $failed = 0
    foreach ($file in $filesToDelete) {
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $deleted++
        } catch {
            Write-Error "Failed to delete $($file.Name): $_"
            $failed++
        }
    }
    
    Write-Info ""
    if ($deleted -gt 0) {
        Write-Ok "Deleted $deleted file(s), freed $totalSizeMB MB"
    }
    if ($failed -gt 0) {
        Write-Error "Failed to delete $failed file(s)"
    }
} else {
    Write-Info ""
    Write-Warn "Preview complete. Run without -WhatIf to actually delete files."
}

Write-Info ""


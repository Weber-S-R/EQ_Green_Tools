# EQGT_Config.psm1
# Author: Scott R. Weber
# LinkedIn: https://www.linkedin.com/in/scottweber1985
# Purpose: Standardized configuration management for EQ Green Tools using environment variables
# Description: Provides centralized configuration with environment variable support,
#              auto-detection of paths, and fallback mechanisms for maximum compatibility
# Version: 2.0
# Release: 2025-11-18

# ============================================================================
# SECTION: Version Information
# ============================================================================

$script:EQGTVersion = "2.0"
$script:EQGTModuleName = "EQGT_Config"
$script:EQGTModuleVersion = "2.0"

# ============================================================================
# SECTION: Module Variables
# ============================================================================

$script:ConfigCache = @{}

# ============================================================================
# SECTION: Helper Functions
# ============================================================================

function Write-ConfigInfo {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-ConfigOk {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-ConfigWarn {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

# ============================================================================
# SECTION: Environment Variable Management
# ============================================================================

<#
.SYNOPSIS
    Gets a configuration value from environment variable with fallback to default
.DESCRIPTION
    Checks environment variable first, then falls back to provided default value.
    Supports both User and Process level environment variables.
.PARAMETER EnvVarName
    Name of the environment variable (without $env: prefix)
.PARAMETER DefaultValue
    Default value to use if environment variable is not set
.PARAMETER Scope
    Scope to check: 'Process' (current session), 'User' (user-level), 'Machine' (system-wide), or 'All' (checks all)
.EXAMPLE
    Get-EQGTConfigValue -EnvVarName "EQGT_EQEMU_PATH" -DefaultValue "C:\EQEmu"
#>
function Get-EQGTConfigValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EnvVarName,
        
        [Parameter(Mandatory=$false)]
        [string]$DefaultValue = "",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Process', 'User', 'Machine', 'All')]
        [string]$Scope = 'All'
    )
    
    # Check cache first
    if ($script:ConfigCache.ContainsKey($EnvVarName)) {
        return $script:ConfigCache[$EnvVarName]
    }
    
    $value = $null
    
    # Check environment variables based on scope
    if ($Scope -eq 'All' -or $Scope -eq 'Process') {
        $value = [Environment]::GetEnvironmentVariable($EnvVarName, 'Process')
        if ($value) {
            $script:ConfigCache[$EnvVarName] = $value
            return $value
        }
    }
    
    if ($Scope -eq 'All' -or $Scope -eq 'User') {
        $value = [Environment]::GetEnvironmentVariable($EnvVarName, 'User')
        if ($value) {
            $script:ConfigCache[$EnvVarName] = $value
            return $value
        }
    }
    
    if ($Scope -eq 'All' -or $Scope -eq 'Machine') {
        $value = [Environment]::GetEnvironmentVariable($EnvVarName, 'Machine')
        if ($value) {
            $script:ConfigCache[$EnvVarName] = $value
            return $value
        }
    }
    
    # Use default if provided
    if ($DefaultValue) {
        $script:ConfigCache[$EnvVarName] = $DefaultValue
        return $DefaultValue
    }
    
    return $null
}

<#
.SYNOPSIS
    Sets an environment variable for the current process
.DESCRIPTION
    Sets an environment variable at the Process level (session-only) or User level (persistent)
.PARAMETER EnvVarName
    Name of the environment variable
.PARAMETER Value
    Value to set
.PARAMETER Scope
    'Process' (session-only) or 'User' (persistent, requires write access)
.EXAMPLE
    Set-EQGTConfigValue -EnvVarName "EQGT_EQEMU_PATH" -Value "D:\MyEQEmu" -Scope "User"
#>
function Set-EQGTConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EnvVarName,
        
        [Parameter(Mandatory=$true)]
        [string]$Value,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Process', 'User')]
        [string]$Scope = 'Process'
    )
    
    [Environment]::SetEnvironmentVariable($EnvVarName, $Value, $Scope)
    $script:ConfigCache[$EnvVarName] = $Value
    
    if ($Scope -eq 'User') {
        Write-ConfigOk "Set $EnvVarName = $Value (persistent, user-level)"
    } else {
        Write-ConfigOk "Set $EnvVarName = $Value (session-only)"
    }
}

# ============================================================================
# SECTION: Path Auto-Detection
# ============================================================================

<#
.SYNOPSIS
    Auto-detects EQEmu installation directory by searching for inventory files
.DESCRIPTION
    Searches common installation locations and any directory containing *-Inventory.txt files
    to find where EverQuest Project 1999 stores inventory exports.
.PARAMETER SearchPaths
    Additional custom paths to search (optional)
.EXAMPLE
    $eqemuPath = Find-EQGTEQEmuPath
#>
function Find-EQGTEQEmuPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$SearchPaths = @()
    )
    
    Write-ConfigInfo "Auto-detecting EQEmu installation directory..."
    
    # Standard default location
    $defaultPath = "C:\EQEmu"
    if (Test-Path -LiteralPath $defaultPath) {
        $invFiles = Get-ChildItem -Path $defaultPath -Filter "*-Inventory.txt" -ErrorAction SilentlyContinue
        if ($invFiles.Count -gt 0) {
            Write-ConfigOk "Found inventory files in default location: $defaultPath"
            return $defaultPath
        }
    }
    
    # Common alternative locations
    $commonPaths = @(
        "C:\Program Files\EQEmu",
        "C:\Program Files (x86)\EQEmu",
        "D:\EQEmu",
        "E:\EQEmu",
        "C:\Games\EQEmu",
        "C:\Games\Project1999",
        "C:\Project1999",
        "$env:USERPROFILE\Documents\EQEmu",
        "$env:USERPROFILE\Documents\Project1999",
        "$env:USERPROFILE\Desktop\EQEmu",
        "$env:USERPROFILE\Desktop\Project1999"
    )
    
    # Add custom search paths
    $allSearchPaths = $commonPaths + $SearchPaths
    
    # Search each path
    foreach ($path in $allSearchPaths) {
        if (Test-Path -LiteralPath $path) {
            $invFiles = Get-ChildItem -Path $path -Filter "*-Inventory.txt" -ErrorAction SilentlyContinue
            if ($invFiles.Count -gt 0) {
                Write-ConfigOk "Found inventory files in: $path"
                return $path
            }
        }
    }
    
    # Search all drives for directories containing *-Inventory.txt files
    Write-ConfigInfo "Searching all drives for inventory files (this may take a moment)..."
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }
    
    foreach ($drive in $drives) {
        $rootPath = $drive.Root
        try {
            # Search in root and common subdirectories (limit depth for performance)
            $searchPaths = @(
                $rootPath,
                (Join-Path $rootPath "EQEmu"),
                (Join-Path $rootPath "Games"),
                (Join-Path $rootPath "Program Files"),
                (Join-Path $rootPath "Program Files (x86)"),
                (Join-Path $rootPath "Users\$env:USERNAME\Documents"),
                (Join-Path $rootPath "Users\$env:USERNAME\Desktop")
            )
            
            foreach ($searchPath in $searchPaths) {
                if (Test-Path -LiteralPath $searchPath) {
                    $invFiles = Get-ChildItem -Path $searchPath -Filter "*-Inventory.txt" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($invFiles) {
                        $foundPath = Split-Path -Path $invFiles.FullName -Parent
                        Write-ConfigOk "Found inventory file in: $foundPath"
                        return $foundPath
                    }
                }
            }
        } catch {
            # Skip drives that can't be accessed
            continue
        }
    }
    
    # If nothing found, return default (user can override)
    Write-ConfigWarn "Could not auto-detect EQEmu path. Using default: $defaultPath"
    Write-ConfigWarn "Set EQGT_EQEMU_PATH environment variable to specify custom location."
    return $defaultPath
}

# ============================================================================
# SECTION: Standardized Configuration Properties
# ============================================================================

<#
.SYNOPSIS
    Gets the EQEmu installation path with auto-detection fallback
.DESCRIPTION
    Returns the EQEmu path from environment variable, or auto-detects it if not set.
.EXAMPLE
    $path = Get-EQGTEQEmuPath
#>
function Get-EQGTEQEmuPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    # Check environment variable first
    $envPath = Get-EQGTConfigValue -EnvVarName "EQGT_EQEMU_PATH" -DefaultValue ""
    
    if ($envPath -and (Test-Path -LiteralPath $envPath)) {
        # Verify it has inventory files
        $invFiles = Get-ChildItem -Path $envPath -Filter "*-Inventory.txt" -ErrorAction SilentlyContinue
        if ($invFiles.Count -gt 0) {
            return $envPath
        } else {
            Write-ConfigWarn "EQGT_EQEMU_PATH set to '$envPath' but no inventory files found. Auto-detecting..."
        }
    }
    
    # Auto-detect if not set or invalid
    return Find-EQGTEQEmuPath
}

<#
.SYNOPSIS
    Gets the script root directory (where EQGT scripts are located)
.DESCRIPTION
    Returns the directory containing the EQGT scripts, with environment variable override support.
.EXAMPLE
    $scriptRoot = Get-EQGTScriptRoot
#>
function Get-EQGTScriptRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $envPath = Get-EQGTConfigValue -EnvVarName "EQGT_SCRIPT_ROOT" -DefaultValue ""
    
    if ($envPath -and (Test-Path -LiteralPath $envPath)) {
        return $envPath
    }
    
    # Default to directory containing this module
    $modulePath = $PSScriptRoot
    if (-not $modulePath) {
        $modulePath = Split-Path -Parent $MyInvocation.PSCommandPath
    }
    
    return $modulePath
}

<#
.SYNOPSIS
    Gets the cache directory path
.DESCRIPTION
    Returns the directory for cache files, with environment variable override support.
.EXAMPLE
    $cacheDir = Get-EQGTCacheDirectory
#>
function Get-EQGTCacheDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $envPath = Get-EQGTConfigValue -EnvVarName "EQGT_CACHE_DIR" -DefaultValue ""
    
    if ($envPath -and (Test-Path -LiteralPath $envPath)) {
        return $envPath
    }
    
    # Default to script root
    return Get-EQGTScriptRoot
}

<#
.SYNOPSIS
    Gets the output directory path for generated reports
.DESCRIPTION
    Returns the directory for output files (CSV, Markdown, etc.), with environment variable override support.
.EXAMPLE
    $outputDir = Get-EQGTOutputDirectory
#>
function Get-EQGTOutputDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $envPath = Get-EQGTConfigValue -EnvVarName "EQGT_OUTPUT_DIR" -DefaultValue ""
    
    if ($envPath -and (Test-Path -LiteralPath $envPath)) {
        return $envPath
    }
    
    # Default to script root
    return Get-EQGTScriptRoot
}

<#
.SYNOPSIS
    Gets the PigParse API base URL
.DESCRIPTION
    Returns the PigParse API base URL, with environment variable override support.
.EXAMPLE
    $apiUrl = Get-EQGTPigParseApiUrl
#>
function Get-EQGTPigParseApiUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    return Get-EQGTConfigValue -EnvVarName "EQGT_PIGPARSE_API_URL" -DefaultValue "https://www.pigparse.org"
}

<#
.SYNOPSIS
    Gets the cache file path for PigParse data
.DESCRIPTION
    Returns the full path to the PigParse cache file.
.EXAMPLE
    $cacheFile = Get-EQGTPigParseCachePath
#>
function Get-EQGTPigParseCachePath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $cacheDir = Get-EQGTCacheDirectory
    return Join-Path $cacheDir "EQGT_cache_pigparse_green.json"
}

<#
.SYNOPSIS
    Gets the configuration file path
.DESCRIPTION
    Returns the full path to the PigParse configuration file.
.EXAMPLE
    $configFile = Get-EQGTPigParseConfigPath
#>
function Get-EQGTPigParseConfigPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $scriptRoot = Get-EQGTScriptRoot
    return Join-Path $scriptRoot "EQGT_pigparse_config.json"
}

<#
.SYNOPSIS
    Gets the inventory file path for a character
.DESCRIPTION
    Returns the full path to a character's inventory file, with auto-detection of EQEmu path.
.PARAMETER CharacterName
    Name of the character
.PARAMETER EQEmuPath
    Optional custom EQEmu path (overrides auto-detection)
.EXAMPLE
    $invPath = Get-EQGTInventoryPath -CharacterName "Friartuc"
#>
function Get-EQGTInventoryPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CharacterName,
        
        [Parameter(Mandatory=$false)]
        [string]$EQEmuPath = ""
    )
    
    if (-not $EQEmuPath) {
        $EQEmuPath = Get-EQGTEQEmuPath
    }
    
    return Join-Path $EQEmuPath "$CharacterName-Inventory.txt"
}

# ============================================================================
# SECTION: Character List Management
# ============================================================================

<#
.SYNOPSIS
    Gets the list of characters to process
.DESCRIPTION
    Returns character list from environment variable or default list.
    Environment variable should be comma-separated: "Char1,Char2,Char3"
.EXAMPLE
    $chars = Get-EQGTCharacterList
#>
function Get-EQGTCharacterList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    
    $envChars = Get-EQGTConfigValue -EnvVarName "EQGT_CHARACTER_LIST" -DefaultValue ""
    
    if ($envChars) {
        return $envChars -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    
    # Default character list (can be overridden)
    return @('Nebuchadnezzarr', 'Aedonis', 'Desaraeus', 'Prismatix', 'Badscot', 'Bigmasher', 
             'Birchwood', 'Bruceknee', 'Bukobgar', 'Crushermoosher', 'Entomb', 'Friartuc', 
             'Gnomine', 'Highburn', 'Mukbut', 'Nautemili', 'Trueoak')
}

# ============================================================================
# SECTION: Version Information
# ============================================================================

<#
.SYNOPSIS
    Gets the EQGT toolset version information
.DESCRIPTION
    Returns version information for the EQGT toolset.
.EXAMPLE
    $version = Get-EQGTVersion
#>
function Get-EQGTVersion {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    return [PSCustomObject]@{
        Version = $script:EQGTVersion
        ModuleName = $script:EQGTModuleName
        ModuleVersion = $script:EQGTModuleVersion
    }
}

# ============================================================================
# SECTION: Configuration Validation
# ============================================================================

<#
.SYNOPSIS
    Validates and displays current configuration
.DESCRIPTION
    Shows all current configuration values and validates paths exist.
.EXAMPLE
    Test-EQGTConfiguration
#>
function Test-EQGTConfiguration {
    [CmdletBinding()]
    param()
    
    Write-Host "`n=== EQGT Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Version Information
    $version = Get-EQGTVersion
    Write-Host "EQGT Toolset Version: $($version.Version)" -ForegroundColor Cyan
    Write-Host "Config Module: $($version.ModuleName) v$($version.ModuleVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # EQEmu Path
    $eqemuPath = Get-EQGTEQEmuPath
    Write-Host "EQEmu Path: $eqemuPath" -ForegroundColor $(if (Test-Path $eqemuPath) { "Green" } else { "Yellow" })
    $invFiles = Get-ChildItem -Path $eqemuPath -Filter "*-Inventory.txt" -ErrorAction SilentlyContinue
    Write-Host "  Inventory files found: $($invFiles.Count)" -ForegroundColor $(if ($invFiles.Count -gt 0) { "Green" } else { "Yellow" })
    
    # Script Root
    $scriptRoot = Get-EQGTScriptRoot
    Write-Host "`nScript Root: $scriptRoot" -ForegroundColor $(if (Test-Path $scriptRoot) { "Green" } else { "Yellow" })
    
    # Cache Directory
    $cacheDir = Get-EQGTCacheDirectory
    Write-Host "Cache Directory: $cacheDir" -ForegroundColor $(if (Test-Path $cacheDir) { "Green" } else { "Yellow" })
    
    # Output Directory
    $outputDir = Get-EQGTOutputDirectory
    Write-Host "Output Directory: $outputDir" -ForegroundColor $(if (Test-Path $outputDir) { "Green" } else { "Yellow" })
    
    # PigParse API
    $apiUrl = Get-EQGTPigParseApiUrl
    Write-Host "`nPigParse API URL: $apiUrl" -ForegroundColor Cyan
    
    # Character List
    $chars = Get-EQGTCharacterList
    Write-Host "`nCharacter List ($($chars.Count) characters):" -ForegroundColor Cyan
    $chars | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    
    # Environment Variables
    Write-Host "`nEnvironment Variables:" -ForegroundColor Cyan
    $envVars = @('EQGT_EQEMU_PATH', 'EQGT_SCRIPT_ROOT', 'EQGT_CACHE_DIR', 'EQGT_OUTPUT_DIR', 
                 'EQGT_PIGPARSE_API_URL', 'EQGT_CHARACTER_LIST')
    foreach ($var in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($var, 'Process')
        if (-not $value) { $value = [Environment]::GetEnvironmentVariable($var, 'User') }
        if (-not $value) { $value = [Environment]::GetEnvironmentVariable($var, 'Machine') }
        $status = if ($value) { "✓ Set" } else { "✗ Not set" }
        $color = if ($value) { "Green" } else { "Gray" }
        Write-Host "  $var : $status" -ForegroundColor $color
        if ($value) {
            Write-Host "    Value: $value" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
}

# Export module members
Export-ModuleMember -Function @(
    'Get-EQGTVersion',
    'Get-EQGTConfigValue',
    'Set-EQGTConfigValue',
    'Find-EQGTEQEmuPath',
    'Get-EQGTEQEmuPath',
    'Get-EQGTScriptRoot',
    'Get-EQGTCacheDirectory',
    'Get-EQGTOutputDirectory',
    'Get-EQGTPigParseApiUrl',
    'Get-EQGTPigParseCachePath',
    'Get-EQGTPigParseConfigPath',
    'Get-EQGTInventoryPath',
    'Get-EQGTCharacterList',
    'Test-EQGTConfiguration'
)


# EQGT Configuration Guide
## Version 2.0 - Standardized Configuration with Environment Variables

**Author:** Scott R. Weber  
**LinkedIn:** https://www.linkedin.com/in/scottweber1985  
**Version:** 2.0

---

## Overview

EQGT Version 2.0 introduces a standardized configuration system using environment variables and automatic path detection. This makes the toolset more user-friendly and portable, allowing it to work seamlessly across different installation locations and user setups.

---

## Key Features

### ✅ Environment Variable Support
- All paths and settings can be configured via environment variables
- Supports Process, User, and Machine-level variables
- Automatic fallback to defaults if variables not set

### ✅ Automatic Path Detection
- Auto-detects EQEmu installation directory
- Searches common installation locations
- Finds inventory files across all drives if needed

### ✅ Backward Compatibility
- All scripts still accept command-line parameters
- Parameters override environment variables
- Works out-of-the-box with default settings

---

## Environment Variables

### EQGT_EQEMU_PATH
**Purpose:** Specifies the directory containing EverQuest inventory files  
**Default:** Auto-detected (searches common locations)  
**Example:**
```powershell
# Set for current session
$env:EQGT_EQEMU_PATH = "D:\MyEQEmu"

# Set permanently (User-level)
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "D:\MyEQEmu", "User")
```

**Auto-Detection Locations:**
- `C:\EQEmu` (default)
- `C:\Program Files\EQEmu`
- `C:\Program Files (x86)\EQEmu`
- `D:\EQEmu`, `E:\EQEmu` (other drives)
- `C:\Games\EQEmu`, `C:\Games\Project1999`
- `$env:USERPROFILE\Documents\EQEmu`
- Searches all drives for directories containing `*-Inventory.txt` files

---

### EQGT_SCRIPT_ROOT
**Purpose:** Specifies the directory containing EQGT scripts  
**Default:** Directory containing the scripts (auto-detected)  
**Example:**
```powershell
$env:EQGT_SCRIPT_ROOT = "C:\Scripts\EQ_Green"
```

---

### EQGT_CACHE_DIR
**Purpose:** Directory for cache files (PigParse price cache)  
**Default:** Same as script root  
**Example:**
```powershell
$env:EQGT_CACHE_DIR = "C:\EQGT\Cache"
```

---

### EQGT_OUTPUT_DIR
**Purpose:** Directory for generated output files (CSV, Markdown reports)  
**Default:** Same as script root  
**Example:**
```powershell
$env:EQGT_OUTPUT_DIR = "C:\EQGT\Reports"
```

---

### EQGT_PIGPARSE_API_URL
**Purpose:** Base URL for PigParse API  
**Default:** `https://api.pigparse.org`  
**Example:**
```powershell
$env:EQGT_PIGPARSE_API_URL = "https://api.pigparse.org"
```

---

### EQGT_CHARACTER_LIST
**Purpose:** Comma-separated list of character names to process  
**Default:** Built-in character list  
**Example:**
```powershell
$env:EQGT_CHARACTER_LIST = "Friartuc,Desaraeus,Prismatix"
```

---

## Quick Start

### Option 1: Use Defaults (Recommended for First-Time Users)
Just run the scripts - they will auto-detect everything:
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
```

### Option 2: Set Environment Variables
Set your custom paths once, then all scripts use them:
```powershell
# Set EQEmu path permanently
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "D:\MyEQEmu", "User")

# Set output directory
[Environment]::SetEnvironmentVariable("EQGT_OUTPUT_DIR", "D:\EQGT\Reports", "User")

# Restart PowerShell or reload environment
```

### Option 3: Use Command-Line Parameters
Override settings per-script execution:
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -EQEmuPath "D:\MyEQEmu" -AllItems
```

---

## Configuration Functions

### Get-EQGTVersion
Get the current EQGT toolset version:
```powershell
Import-Module .\EQGT_Config.psm1
$version = Get-EQGTVersion
Write-Host "EQGT Version: $($version.Version)"
```

### Test-EQGTConfiguration
Display and validate current configuration:
```powershell
Import-Module .\EQGT_Config.psm1
Test-EQGTConfiguration
```

**Output shows:**
- EQGT Toolset Version
- EQEmu Path (with inventory file count)
- Script Root
- Cache Directory
- Output Directory
- PigParse API URL
- Character List
- Environment Variable Status

### Get-EQGTEQEmuPath
Get the EQEmu path (with auto-detection):
```powershell
$eqemuPath = Get-EQGTEQEmuPath
Write-Host "EQEmu Path: $eqemuPath"
```

### Set-EQGTConfigValue
Set a configuration value:
```powershell
Set-EQGTConfigValue -EnvVarName "EQGT_EQEMU_PATH" -Value "D:\MyEQEmu" -Scope "User"
```

---

## Auto-Detection Details

### How Auto-Detection Works

1. **Check Environment Variable:** First checks if `EQGT_EQEMU_PATH` is set
2. **Check Default Location:** Looks in `C:\EQEmu`
3. **Check Common Locations:** Searches standard installation paths
4. **Search All Drives:** If not found, searches all drives for `*-Inventory.txt` files
5. **Fallback:** Returns default path if nothing found (user can still override)

### Performance

- **Fast:** Checks common locations first (milliseconds)
- **Thorough:** Full drive search only if needed (may take 10-30 seconds)
- **Cached:** Results are cached during script execution

---

## Migration from Version 1.0

### What Changed

1. **Path Handling:** Scripts now use `Get-EQGTEQEmuPath` instead of hardcoded `C:\EQEmu`
2. **Output Files:** Now saved to configured output directory instead of script directory
3. **Character Lists:** Now configurable via environment variable
4. **Module Import:** All scripts import `EQGT_Config.psm1` module

### Backward Compatibility

✅ **Fully Compatible:** All existing command-line parameters still work  
✅ **No Breaking Changes:** Scripts work the same way, just more flexible  
✅ **Auto-Detection:** Works even if you don't set any environment variables

### Example Migration

**Before (v1.0):**
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -EQEmuPath "C:\EQEmu" -AllItems
```

**After (v2.0) - Same command works:**
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
# Auto-detects EQEmu path, no need to specify
```

**Or set once, use everywhere:**
```powershell
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "D:\MyEQEmu", "User")
# Now all scripts use D:\MyEQEmu automatically
```

---

## Troubleshooting

### "Could not load EQGT_Config module"
**Solution:** Ensure `EQGT_Config.psm1` is in the same directory as the scripts. Scripts will fall back to defaults if module can't be loaded.

### Auto-Detection Not Finding Inventory Files
**Solution:** 
1. Verify inventory files exist: `Get-ChildItem -Path "C:\EQEmu" -Filter "*-Inventory.txt"`
2. Set `EQGT_EQEMU_PATH` environment variable manually
3. Use `-EQEmuPath` parameter on command line

### Output Files in Wrong Location
**Solution:**
1. Set `EQGT_OUTPUT_DIR` environment variable
2. Or specify full path in `-OutputCsv` and `-OutputMarkdown` parameters

### Character List Not Updating
**Solution:**
1. Set `EQGT_CHARACTER_LIST` environment variable
2. Or edit the default list in `EQGT_Config.psm1` (function `Get-EQGTCharacterList`)

---

## Best Practices

### 1. Set User-Level Environment Variables
Set once, use everywhere:
```powershell
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "D:\MyEQEmu", "User")
[Environment]::SetEnvironmentVariable("EQGT_OUTPUT_DIR", "D:\EQGT\Reports", "User")
```

### 2. Use Test-EQGTConfiguration
Verify your setup:
```powershell
Import-Module .\EQGT_Config.psm1
Test-EQGTConfiguration
```

### 3. Keep Scripts Together
Place all EQGT scripts in the same directory for best compatibility.

### 4. Organize Output Files
Set a dedicated output directory to keep reports organized:
```powershell
$env:EQGT_OUTPUT_DIR = "C:\EQGT\Reports"
```

---

## Examples

### Example 1: First-Time Setup
```powershell
# Just run the script - auto-detection handles everything
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
```

### Example 2: Custom Installation Location
```powershell
# Set path once
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "D:\Games\Project1999", "User")

# All scripts now use this path automatically
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
.\EQGT_Character_Inventory_Analyzer.ps1
```

### Example 3: Multiple Users / Shared Setup
```powershell
# Set machine-level variable (requires admin)
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "\\Server\Shared\EQEmu", "Machine")
```

### Example 4: Custom Character List
```powershell
# Set your character list
$env:EQGT_CHARACTER_LIST = "MyChar1,MyChar2,MyChar3"

# Analyzer now uses your list
.\EQGT_Character_Inventory_Analyzer.ps1
```

### Example 5: Verify Configuration
```powershell
Import-Module .\EQGT_Config.psm1

# Check version
$version = Get-EQGTVersion
Write-Host "EQGT Version: $($version.Version)"

# Test configuration
Test-EQGTConfiguration

# Get specific paths
$eqemuPath = Get-EQGTEQEmuPath
$outputDir = Get-EQGTOutputDirectory
Write-Host "EQEmu: $eqemuPath"
Write-Host "Output: $outputDir"
```

---

## Technical Details

### Module Structure
- **EQGT_Config.psm1:** Centralized configuration module
- **All Scripts:** Import and use config module functions
- **Fallback:** Scripts work even if module can't be loaded

### Environment Variable Priority
1. Process-level (current session)
2. User-level (persistent for user)
3. Machine-level (system-wide)
4. Default values

### Path Resolution Order
1. Command-line parameter (highest priority)
2. Environment variable
3. Auto-detection
4. Default value (lowest priority)

---

## Summary

EQGT Version 2.0 provides:
- ✅ **Standardized Configuration** via environment variables
- ✅ **Automatic Path Detection** for easy setup
- ✅ **Backward Compatibility** with existing usage
- ✅ **Flexibility** for different installation scenarios
- ✅ **User-Friendly** defaults that "just work"

**No configuration required** - scripts work out-of-the-box with auto-detection, but you can customize everything via environment variables if needed.

---

**Last Updated:** 2025-01-XX  
**EQGT Version:** 2.0


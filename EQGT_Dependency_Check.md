# EQGT Dependency Check Report
## Version 2.0

**Date:** 2025-01-XX  
**Status:** ✅ All Dependencies Resolved

---

## Dependency Analysis

### ✅ No External Dependencies
- **No 3X0 Toolset Dependencies:** All 3X0 references have been removed
- **No External Modules Required:** Only uses built-in PowerShell cmdlets
- **Self-Contained:** All scripts work standalone

### ✅ Internal Dependencies (Self-Contained)
- **EQGT_Config.psm1:** Configuration module (part of EQGT toolset)
  - Provides environment variable support
  - Auto-detection functions
  - All scripts include fallback functions if module unavailable

### ✅ Fallback Mechanisms
All scripts include fallback functions that provide default behavior if `EQGT_Config.psm1` cannot be loaded:
- `Get-EQGTEQEmuPath` → Returns `"C:\EQEmu"`
- `Get-EQGTOutputDirectory` → Returns script directory
- `Get-EQGTScriptRoot` → Returns script directory
- `Get-EQGTInventoryPath` → Constructs path from character name
- `Get-EQGTCharacterList` → Returns default character list
- `Get-EQGTPigParseCachePath` → Returns default cache path
- `Get-EQGTPigParseApiUrl` → Returns `"https://api.pigparse.org"`

---

## Function Name Changes

### Fixed: Removed 3X0 Naming
- ✅ `Invoke-3X0Http` → `Invoke-EQGTHttp` (in EQGT_PigParse_Scraper.ps1)
- ✅ All function names now use `EQGT_` prefix
- ✅ All output text updated from "3X0" to "EQGT"

---

## Script Dependencies

### EQGT_EC_Gem_Pricer.ps1
- **Imports:** EQGT_Config.psm1 (with fallback)
- **Uses:** EQGT_PigParse_Scraper.ps1
- **Dependencies:** None external

### EQGT_Character_Inventory_Analyzer.ps1
- **Imports:** EQGT_Config.psm1 (with fallback)
- **Dependencies:** None external

### EQGT_Inventory_Table_Viewer.ps1
- **Imports:** EQGT_Config.psm1 (with fallback)
- **Dependencies:** None external

### EQGT_PigParse_Scraper.ps1
- **Imports:** EQGT_Config.psm1 (with fallback)
- **Dependencies:** None external
- **Optional:** Microsoft Edge (for fallback HTML scraping, not required)

### EQGT_Config.psm1
- **Dependencies:** None external
- **Pure PowerShell:** Uses only built-in cmdlets

---

## Hardcoded Paths (Acceptable)

### Auto-Detection Search Paths
These are search paths for auto-detection, not dependencies:
- `C:\EQEmu` (default)
- `C:\Program Files\EQEmu`
- `C:\Program Files (x86)\EQEmu`
- Various user profile paths
- **Purpose:** To find inventory files automatically
- **Impact:** None - these are just search locations

### Optional Edge Paths
- `C:\Program Files\Microsoft\Edge\Application\msedge.exe`
- `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- **Purpose:** Fallback HTML scraping (optional)
- **Impact:** None - only used if API fails, script works without it

---

## Verification Checklist

- ✅ No `Import-Module` calls to external modules
- ✅ No `3X0` function names or references
- ✅ No hardcoded dependencies on 3X0 toolset
- ✅ All scripts include fallback functions
- ✅ All paths use environment variables or auto-detection
- ✅ Scripts work standalone without config module
- ✅ Only uses built-in PowerShell cmdlets

---

## Conclusion

**✅ EQGT Toolset is fully standalone and has no external dependencies.**

All scripts:
- Work independently
- Include fallback mechanisms
- Use only built-in PowerShell features
- Are portable and can be shared without requiring 3X0 toolset
- Handle missing config module gracefully

**Ready for distribution!**


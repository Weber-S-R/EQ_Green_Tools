# EQGT V3.0 Final Release Updates

**V2.0 Release Date:** 2025-11-18  
**V3.0 Release Date:** 2025-11-19  
**Last Updated:** 2025-11-19  
**Purpose:** Final release changelog for V3.0 - All bugs fixed, stable release

---

## Special Thanks

**Thank you to Cadilac/Exandr for helping me dev test and give insight to this project. Without it, this would not be the product you see here today. Thank you!**

---

## V3.0 Final Release Summary

### ✅ All Critical Bugs Fixed
- **DNS/API Issue Resolved**: Changed API endpoint from `api.pigparse.org` (non-existent) to `www.pigparse.org` (working)
- **HTTP Method Fixed**: Switched from `Invoke-WebRequest` to `Invoke-RestMethod` for better JSON handling
- **Param Block Fixed**: Corrected PowerShell param block syntax errors
- **Cache Generation Working**: Successfully downloads and caches 9,021 items in ~2 seconds
- **Price Lookups Working**: 92% success rate (45/49 items priced in test run)

### 🆕 New Features Added
1. **Built-in Diagnostics** (`Test-EQGTPriceSystem` function)
2. **Comprehensive DNS Testing** in diagnostic script
3. **Auto-Cleanup Integration** (runs when cache expires)
4. **Progress Feedback** during cache generation
5. **Standalone Diagnostic Tool** (`EQGT_Diagnose_Pricing.ps1`)
6. **Cleanup Utility** (`EQGT_Cleanup_Output_Files.ps1` with `-Force` option)

### 🔧 Enhancements
- Better error messages throughout
- Time estimates for long operations
- Cache creation confirmation
- Improved retry logic
- Enhanced protection for inventory files

---

## Complete Change Log

### Scripts Modified

| Script | V2.0 State | V3.0 Changes | Status |
|--------|-----------|--------------|--------|
| **EQGT_EC_Gem_Pricer.ps1** | Working with TBD prices issue | • Fixed param block syntax<br>• Added built-in diagnostics<br>• Fixed API endpoint (www.pigparse.org)<br>• Better error handling<br>• Added fallback functions | ✅ Fixed |
| **EQGT_PigParse_Scraper.ps1** | API calls failing | • Changed to Invoke-RestMethod<br>• Fixed API URL to www.pigparse.org<br>• Added progress feedback<br>• Auto-cleanup integration<br>• Better error messages | ✅ Fixed |
| **EQGT_Config.psm1** | Working | • Updated default API URL to www.pigparse.org | ✅ Updated |
| **EQGT_Diagnose_Pricing.ps1** | New in V3.0 | • Comprehensive DNS testing<br>• Network connectivity tests<br>• API endpoint validation<br>• Cache verification | 🆕 New |
| **EQGT_Cleanup_Output_Files.ps1** | New in V3.0 | • Auto-cleanup on cache expiry<br>• -Force parameter<br>• Protection for inventory files<br>• Scheduled cleanup integration | 🆕 New |

### Scripts Removed
- ❌ **EQGT_PigParse_API.ps1** - Unused, deleted
- ❌ **EQGT_PigParse_Examples.ps1** - Referenced deleted script, removed

---

## Technical Fixes

### 1. DNS/API Endpoint Issue
**Problem**: `api.pigparse.org` does not exist in DNS  
**Solution**: Changed all references to `www.pigparse.org`  
**Files Updated**:
- `EQGT_Config.psm1`
- `EQGT_PigParse_Scraper.ps1`
- `EQGT_EC_Gem_Pricer.ps1`
- `EQGT_Diagnose_Pricing.ps1`

### 2. HTTP Method Issue
**Problem**: `Invoke-WebRequest` had issues with JSON parsing  
**Solution**: Switched to `Invoke-RestMethod` which auto-parses JSON  
**File Updated**: `EQGT_PigParse_Scraper.ps1`

### 3. Param Block Syntax
**Problem**: PowerShell param block had syntax errors  
**Solution**: Fixed param block placement and default value handling  
**File Updated**: `EQGT_EC_Gem_Pricer.ps1`

### 4. Cache Generation
**Problem**: Cache generation was failing silently  
**Solution**: Fixed API endpoint, added progress feedback, better error handling  
**File Updated**: `EQGT_PigParse_Scraper.ps1`

---

## Testing Results

### Test Run: Friartuc Inventory
- **Total Items**: 49
- **Items with Prices**: 45 (92% success rate)
- **Items without Prices**: 4 (not in PigParse database - expected)
- **Grand Total**: 13,376 PP
- **Cache Generation**: 9,021 items in 1.9 seconds
- **API Endpoint**: www.pigparse.org (working)

### Features Verified
✅ Auto-cleanup on cache expiry  
✅ Cache generation from API  
✅ Price lookups working  
✅ CSV and Markdown output  
✅ File protection (inventory files safe)  
✅ DNS diagnostics working  
✅ Network connectivity tests working  

---

## File Structure

### Core Scripts (6)
- `EQGT_EC_Gem_Pricer.ps1` - Main pricing script
- `EQGT_PigParse_Scraper.ps1` - API and cache handler
- `EQGT_Config.psm1` - Configuration module
- `EQGT_Character_Inventory_Analyzer.ps1` - Inventory analyzer
- `EQGT_Inventory_Table_Viewer.ps1` - Table viewer
- `EQGT_Diagnose_Pricing.ps1` - Diagnostic tool (NEW)

### Utility Scripts (1)
- `EQGT_Cleanup_Output_Files.ps1` - Cleanup utility (NEW)

### Documentation (4)
- `EQGT_README.md` - Main documentation
- `EQGT_Configuration_Guide.md` - Configuration guide
- `EQGT_DEPENDENCIES.md` - Dependencies list
- `EQGT_V3.0_Release_Updates.md` - Development changelog
- `EQGT_V3.0_Final_Release_Updates.md` - This file (NEW)

### Configuration (1)
- `EQGT_pigparse_config.json` - API configuration

---

## Installation & Usage

### Quick Start
1. Extract all files to a directory (e.g., `C:\Scripts\EQ_Green`)
2. Generate inventory files in-game: `/output inventory`
3. Run pricing script: `.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "YourCharacter" -AllItems`

### First Run
- Script will automatically download price cache (~2 seconds)
- Cache is valid for 7 days
- Subsequent runs use cached data (instant)

### Troubleshooting
- Run `.\EQGT_Diagnose_Pricing.ps1` for comprehensive diagnostics
- Check DNS resolution for www.pigparse.org
- Verify internet connectivity
- Check PowerShell execution policy

---

## Breaking Changes from V2.0

### API Endpoint Change
- **V2.0**: Used `api.pigparse.org` (non-functional)
- **V3.0**: Uses `www.pigparse.org` (working)
- **Impact**: Users must update if they set custom `EQGT_PIGPARSE_API_URL` environment variable

### Removed Scripts
- `EQGT_PigParse_API.ps1` - No longer needed
- `EQGT_PigParse_Examples.ps1` - Referenced deleted script

---

## Known Limitations

1. **Items Not in Database**: Some items may not have prices (e.g., "A Scarlet Stone", certain spells)
   - This is expected behavior - not all items are in PigParse database
   - Success rate: ~92% in testing

2. **Cache Expiry**: Cache expires after 7 days
   - First run after expiry will download fresh data (~2 seconds)
   - Auto-cleanup runs before cache regeneration

3. **Network Dependency**: Requires internet connection for cache generation
   - Works offline with valid cache
   - Diagnostic tool can identify network issues

---

## Performance Metrics

- **Cache Generation**: ~2 seconds for 9,021 items
- **Price Lookup**: Instant (from cache)
- **File Generation**: <1 second for CSV/Markdown
- **Cache Size**: ~3MB (9,021 items)
- **Cache Validity**: 7 days

---

## Version History

### V3.0 (2025-11-19) - Final Release
- ✅ All critical bugs fixed
- ✅ API endpoint corrected
- ✅ HTTP method improved
- ✅ Comprehensive diagnostics added
- ✅ Auto-cleanup integrated
- ✅ Stable and tested

### V2.0 (2025-11-18) - Initial Release
- Basic pricing functionality
- 7-day cache system
- Environment variable configuration
- Auto-path detection

---

## Support & Feedback

For issues or questions:
1. Run `EQGT_Diagnose_Pricing.ps1` first
2. Check documentation files
3. Review this changelog for known issues

---

**V3.0 is stable and ready for production use.**


# EQ Green Tools (EQGT)

**EverQuest Project 1999 Green Server Inventory & Pricing Tools**

A comprehensive PowerShell toolkit for managing and pricing EverQuest inventory items on the Project 1999 Green server. This toolset integrates with PigParse.org to provide real-time pricing data with intelligent caching.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Features](#features)
- [Scripts](#scripts)
- [Usage Examples & Use Cases](#-usage-examples--use-cases)
  - [20 Detailed Use Cases](#detailed-use-cases)
  - [Common Workflows](#-common-workflows)
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [File Structure](#file-structure)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

EQ Green Tools (EQGT) is a standalone PowerShell toolkit designed to help EverQuest players on Project 1999 Green server:

- **Price inventory items** using real-time data from PigParse.org
- **Analyze character inventories** across multiple characters
- **Search items** across all character inventories
- **Generate sell lists** with pricing information
- **Track equipped gems** and valuable items

All tools use a **7-day caching system** to minimize API calls and improve performance.

---

## 🚀 Quick Start

1. **Extract the folder** to any location (e.g., `C:\Scripts\EQ_Green\`)

2. **Ensure dependencies are installed** (see [Dependencies](#dependencies))

3. **Generate inventory files** in-game:
   ```
   /output inventory
   ```
   This creates `CharacterName-Inventory.txt` files in your EQEmu directory (default: `C:\EQEmu\`)

4. **Run a pricing script**:
   ```powershell
   cd C:\Scripts\EQ_Green
   .\EQGT_EC_Gem_Pricer.ps1 -CharacterName "YourCharacter" -AllItems
   ```

---

## ✨ Features

- **Bulk Price Lookup**: Single API call loads all item prices (9,000+ items)
- **7-Day Caching**: Prices cached for 7 days to reduce API load
- **Multi-Character Support**: Analyze inventories across all your characters
- **Flexible Pricing**: Price all items or just sellable items (gems/runes/words/spells)
- **Multiple Output Formats**: CSV and Markdown reports
- **Character Name Support**: Use character names instead of file paths
- **Bank Support**: Include bank items in analysis (optional)

---

## 📜 Scripts

### EQGT_EC_Gem_Pricer.ps1
**Main pricing tool** - Prices items from inventory exports using PigParse data.

**Key Features:**
- Price all items or just sellable items
- Character name or file path support
- Includes/excludes bank items
- Generates CSV and Markdown reports with grand totals

**Usage:**
```powershell
# Price all items for a character
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems

# Price only sellable items (gems/runes/words/spells)
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Desaraeus"

# Use custom inventory file
.\EQGT_EC_Gem_Pricer.ps1 -InventoryPath "C:\EQEmu\MyChar-Inventory.txt" -AllItems

# Include bank items
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems -IncludeBank
```

---

### EQGT_Character_Inventory_Analyzer.ps1
**Inventory analyzer** - Scans all character inventories and categorizes items.

**Key Features:**
- Categorizes items (Gems, Runes, Words, Spells, Research Pages, etc.)
- Identifies sellable items
- Generates summary report
- Shows item counts by category

**Usage:**
```powershell
.\EQGT_Character_Inventory_Analyzer.ps1

# Custom EQEmu path
.\EQGT_Character_Inventory_Analyzer.ps1 -EQEmuPath "D:\MyEQEmu"
```

---

### EQGT_Inventory_Table_Viewer.ps1
**Cross-character item search** - Find items across all characters.

**Key Features:**
- Search for specific items (Runes, Words, Spells, etc.)
- Shows quantities by character in table format
- Filter by item type
- Show empty slots (optional)

**Usage:**
```powershell
# Search for runes
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune"

# Search for words
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Words"

# Search for spells
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Spell:"

# Show gems (default if no search term)
.\EQGT_Inventory_Table_Viewer.ps1

# Show empty slots
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune" -ShowEmpty
```

---

### EQGT_PigParse_Scraper.ps1
**Price scraper** - Bulk price list fetcher with caching (used internally).

### EQGT_Cleanup_Output_Files.ps1
**Output file cleanup** - Removes old generated files (CSV, MD, TXT, MMD) to prevent directory clutter.

**Usage:**
```powershell
# Delete all output files
.\EQGT_Cleanup_Output_Files.ps1

# Keep files newer than 7 days
.\EQGT_Cleanup_Output_Files.ps1 -KeepDays 7

# Keep 5 most recent files of each type
.\EQGT_Cleanup_Output_Files.ps1 -KeepRecent 5

# Preview what would be deleted (safe mode)
.\EQGT_Cleanup_Output_Files.ps1 -WhatIf

# Also delete cache file (will regenerate on next run)
.\EQGT_Cleanup_Output_Files.ps1 -IncludeCache
```

**What it cleans:**
- Pricing CSV/MD files (`EQGT_*_Pricing.*`)
- Sell list files (`EQGT_EC_Sell_List.*`)
- Inventory summaries (`EQGT_Character_Inventory_Summary.txt`)
- Table files (`EQGT_Equipped_Gems_Table.*`)

**What it preserves:**
- All script files (`.ps1`, `.psm1`)
- Documentation (`.md`)
- Configuration files (`.json` - unless `-IncludeCache`)
- Archive files (`.zip`)

---

## 💡 Usage Examples & Use Cases

### Use Case 1: Price All Items in Character's Bags

**Scenario:** You want to know the total value of everything in a character's bags.

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
```

**What it does:**
- Extracts all items from General slots (bags)
- Looks up prices for each item from PigParse
- Calculates total value
- Generates CSV and Markdown reports

**Output:**
- `EQGT_Friartuc_Pricing.csv` - Spreadsheet format for Excel
- `EQGT_Friartuc_Pricing.md` - Formatted report with grand total

**Use when:**
- Preparing to sell items
- Calculating character wealth
- Deciding what to keep vs. sell

---

### Use Case 2: Price Only Sellable Items (Gems/Runes/Words/Spells)

**Scenario:** You only care about items that are commonly sold on the EC tunnel.

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Desaraeus"
```

**What it does:**
- Filters to only gems, runes, words, and spells
- Prices these items
- Ignores equipment, food, trade materials, etc.

**Output:**
- Categorized by type (Gem, Rune, Words, Spell)
- Shows quantities and prices per category

**Use when:**
- Creating an EC tunnel sell list
- Focusing on research components
- Quick valuation of sellable inventory

---

### Use Case 3: Price Items Including Bank

**Scenario:** You want to price everything including what's in the bank.

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems -IncludeBank
```

**What it does:**
- Includes both General slots (bags) AND Bank slots
- Gives complete inventory valuation

**Use when:**
- Full character audit
- Planning major sales
- Complete wealth calculation

---

### Use Case 4: Price Custom Inventory File

**Scenario:** You have inventory files in a non-standard location or want to price a specific file.

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -InventoryPath "D:\MyEQ\MyChar-Inventory.txt" -AllItems
```

**What it does:**
- Uses the exact file path you specify
- Works with any inventory file location

**Use when:**
- Inventory files stored elsewhere
- Analyzing a friend's inventory
- Testing with different inventory exports

---

### Use Case 5: Analyze All Characters for Sellable Items

**Scenario:** You want a summary of what sellable items you have across all characters.

```powershell
.\EQGT_Character_Inventory_Analyzer.ps1
```

**What it does:**
- Scans all character inventory files
- Categorizes items (Gems, Runes, Words, Spells, Research Pages, etc.)
- Lists sellable items with quantities
- Shows which characters have what

**Output:**
- `EQGT_Character_Inventory_Summary.txt` - Complete breakdown

**Use when:**
- Planning what to sell
- Finding where specific items are stored
- Getting overview of all characters

**Example Output:**
```
[Friartuc]
Total Non-Worn Items: 186
  Gem : 26 items
  Rune : 15 items
  Words : 12 items
  Spell : 8 items
  *** SELLABLE: Spell, Rune, Words, Gem ***
    - Black Pearl x1
    - Rune of Al'Kabor x1
    ...
```

---

### Use Case 6: Find Specific Items Across All Characters

**Scenario:** You need to find where you stored all your runes.

```powershell
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune"
```

**What it does:**
- Searches all characters for items matching "Rune"
- Creates a table: Items (rows) × Characters (columns)
- Shows quantities for each character

**Output:**
- Table displayed in console
- Saved to `EQGT_Equipped_Gems_Table.txt` (if gems)

**Use when:**
- Finding where you put specific items
- Consolidating items from multiple characters
- Planning item transfers

**Example Output:**
```
+----------------------------------+--------+----------+-----------+
| Gem                              | Friartuc | Desaraeus | Prismatix |
+----------------------------------+--------+----------+-----------+
| Rune of Al'Kabor                 |    1   |    2     |     0     |
| Rune of Arrest                    |    2   |    0     |     0     |
| Rune of Conception                |    6   |    1     |     0     |
+----------------------------------+--------+----------+-----------+
```

---

### Use Case 7: Search for Words of Power

**Scenario:** You need all Words of Power for research.

```powershell
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Words"
```

**What it does:**
- Finds all items starting with "Words"
- Shows distribution across characters

**Use when:**
- Research planning
- Finding research components
- Completing spell research

---

### Use Case 8: Find All Spells

**Scenario:** You want to see what spells you have across all characters.

```powershell
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Spell:"
```

**What it does:**
- Finds all items starting with "Spell:"
- Lists spell scrolls by character

**Use when:**
- Planning spell learning
- Finding duplicate spells
- Organizing spell collection

---

### Use Case 9: View All Gems (Default)

**Scenario:** You want to see all gems across characters (most common use case).

```powershell
.\EQGT_Inventory_Table_Viewer.ps1
```

**What it does:**
- Default behavior: shows all gems
- Includes equipped gems
- Shows quantities per character

**Use when:**
- Quick gem inventory check
- Planning gem sales
- Finding specific gems

---

### Use Case 10: Show Empty Slots Too

**Scenario:** You want to see which characters have space for items.

```powershell
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune" -ShowEmpty
```

**What it does:**
- Shows all characters, even if they have 0 of that item
- Helps identify where to move items

**Use when:**
- Planning item consolidation
- Finding characters with space
- Complete inventory overview

---

### Use Case 11: Custom Output File Names

**Scenario:** You want to save reports with specific names.

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems -OutputCsv "Friartuc_Value.csv" -OutputMarkdown "Friartuc_Report.md"
```

**What it does:**
- Uses your custom file names
- Useful for organizing multiple reports

**Use when:**
- Creating dated reports
- Organizing by purpose
- Sharing specific reports

---

### Use Case 12: Custom EQEmu Path

**Scenario:** Your EQEmu files are in a different location.

```powershell
.\EQGT_Character_Inventory_Analyzer.ps1 -EQEmuPath "D:\Games\Project1999"
```

**What it does:**
- Looks for inventory files in your custom path
- Works with any directory structure

**Use when:**
- Multiple EQ installations
- Custom file organization
- Shared/network drives

---

### Use Case 13: Price Without API (Offline Mode)

**Scenario:** You want to use cached prices only (no internet).

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems -UsePigParse:$false
```

**What it does:**
- Uses only cached price data
- No API calls made
- Works offline if cache is valid

**Use when:**
- No internet connection
- API is down
- Testing with cached data

**Note:** Requires valid cache file (less than 7 days old).

---

### Use Case 14: Batch Process Multiple Characters

**Scenario:** You want to price all your characters at once.

```powershell
$chars = @("Friartuc", "Desaraeus", "Prismatix", "Aedonis")
foreach ($char in $chars) {
    Write-Host "`n=== Pricing $char ===" -ForegroundColor Cyan
    .\EQGT_EC_Gem_Pricer.ps1 -CharacterName $char -AllItems
}
```

**What it does:**
- Loops through character list
- Prices each character
- Generates separate reports for each

**Use when:**
- Weekly/monthly inventory audits
- Comparing character wealth
- Bulk pricing operations

---

### Use Case 15: Find High-Value Items

**Scenario:** You want to identify your most valuable items.

**Step 1:** Price all items
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems
```

**Step 2:** Open the CSV file in Excel
- Sort by "Total" column (descending)
- Top items are your most valuable

**Use when:**
- Deciding what to sell first
- Identifying valuable items
- Planning major purchases

---

### Use Case 16: Compare Character Wealth

**Scenario:** You want to see which character has the most valuable inventory.

**Step 1:** Price all characters
```powershell
$chars = @("Friartuc", "Desaraeus", "Prismatix")
foreach ($char in $chars) {
    .\EQGT_EC_Gem_Pricer.ps1 -CharacterName $char -AllItems
}
```

**Step 2:** Check the Markdown files
- Each file shows "Grand Total" at the bottom
- Compare totals across characters

**Use when:**
- Wealth distribution analysis
- Planning character focus
- Financial planning

---

### Use Case 17: Create EC Tunnel Sell List

**Scenario:** You want a formatted list for posting in EC tunnel.

**Step 1:** Price sellable items
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc"
```

**Step 2:** Use the Markdown output
- Copy the table from `EQGT_Friartuc_Pricing.md`
- Format for Discord/forum post
- Or use CSV to create custom format

**Use when:**
- Creating sell posts
- Organizing sales
- Pricing items for trade

---

### Use Case 18: Track Inventory Over Time

**Scenario:** You want to track how your inventory value changes.

**Step 1:** Create dated reports
```powershell
$date = Get-Date -Format "yyyy-MM-dd"
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems -OutputCsv "Friartuc_$date.csv" -OutputMarkdown "Friartuc_$date.md"
```

**Step 2:** Compare reports over time
- Run weekly/monthly
- Compare grand totals
- Track value growth

**Use when:**
- Progress tracking
- Financial planning
- Inventory management

---

### Use Case 19: Find Missing Research Components

**Scenario:** You need specific runes/words for a spell.

**Step 1:** Search for the component
```powershell
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune of Al'Kabor"
```

**Step 2:** Check the table
- See which characters have it
- See quantities available

**Use when:**
- Research planning
- Component gathering
- Spell completion

---

### Use Case 20: Inventory Cleanup

**Scenario:** You want to identify items to sell or delete.

**Step 1:** Analyze all characters
```powershell
.\EQGT_Character_Inventory_Analyzer.ps1
```

**Step 2:** Review the summary
- Look for low-value items
- Identify duplicates
- Find items to consolidate

**Step 3:** Price valuable items
```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "CharacterName" -AllItems
```

**Use when:**
- Inventory cleanup
- Space management
- Organization

---

## 🔄 Common Workflows

### Workflow 1: Weekly Inventory Audit
```powershell
# 1. Analyze all characters
.\EQGT_Character_Inventory_Analyzer.ps1

# 2. Price main character
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "MainChar" -AllItems

# 3. Check for specific items
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune"
```

### Workflow 2: Preparing for Sale
```powershell
# 1. Price all sellable items
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "CharName" -AllItems

# 2. Open CSV in Excel
# 3. Sort by value
# 4. Create sell list from top items
```

### Workflow 3: Research Planning
```powershell
# 1. Find all runes
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Rune"

# 2. Find all words
.\EQGT_Inventory_Table_Viewer.ps1 -ItemSearch "Words"

# 3. Price components
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "CharName"
```

### Workflow 4: Character Comparison
```powershell
# Price all characters
foreach ($char in @("Char1", "Char2", "Char3")) {
    .\EQGT_EC_Gem_Pricer.ps1 -CharacterName $char -AllItems
}

# Compare grand totals in generated Markdown files
```

---

## 📦 Dependencies

See [EQGT_DEPENDENCIES.md](EQGT_DEPENDENCIES.md) for complete dependency information.

**Minimum Requirements:**
- Windows PowerShell 5.1+ or PowerShell 7+
- Internet connection (for PigParse API)
- EverQuest Project 1999 client (to generate inventory files)

**No additional modules or installations required!** All dependencies are built into PowerShell.

---

## ⚙️ Configuration

### Inventory File Location
By default, tools look for inventory files in `C:\EQEmu\`. To use a different location:

```powershell
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -EQEmuPath "D:\MyEQEmu" -AllItems
```

### Character List
Edit the character list in scripts to match your characters:
- `EQGT_Character_Inventory_Analyzer.ps1` - Line 55
- `EQGT_Inventory_Table_Viewer.ps1` - Line 46

### Cache Location
Price cache is stored in: `EQGT_cache_pigparse_green.json`
- Automatically created on first run
- Valid for 7 days
- ~3MB file with 9,000+ item prices

---

## 📁 File Structure

```
EQ_Green/
├── EQGT_README.md                          # This file
├── EQGT_Configuration_Guide.md            # Configuration guide (v2.0)
├── EQGT_DEPENDENCIES.md                    # Dependencies guide
├── EQGT_Config.psm1                        # Configuration module (v2.0)
│
├── EQGT_EC_Gem_Pricer.ps1                 # Main pricing tool
├── EQGT_Character_Inventory_Analyzer.ps1  # Inventory analyzer
├── EQGT_Inventory_Table_Viewer.ps1        # Cross-character search
│
├── EQGT_PigParse_Scraper.ps1              # Price scraper (internal)
│
├── EQGT_pigparse_config.json              # API configuration
├── EQGT_cache_pigparse_green.json         # Price cache (auto-generated)
│
└── Output Files (generated):
    ├── EQGT_*_Pricing.csv                 # Pricing spreadsheets
    ├── EQGT_*_Pricing.md                  # Pricing reports
    ├── EQGT_Character_Inventory_Summary.txt
    └── EQGT_Equipped_Gems_Table.txt
```

---

## 🔧 Troubleshooting

### "Input file not found" Error
**Solution:** Generate inventory file in-game:
```
/output inventory
```
File should be at: `C:\EQEmu\CharacterName-Inventory.txt`

### "Could not load bulk price list" Warning
**Solution:** 
- Check internet connection
- Wait a few seconds and try again
- Cache file may be corrupted - delete `EQGT_cache_pigparse_green.json` to refresh

### Prices Show as "TBD"
**Solution:**
- Item may not be in PigParse database
- Try refreshing cache (delete `EQGT_cache_pigparse_green.json`)
- Some items simply don't have pricing data available

### Script Execution Policy Error
**Solution:** Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Character Not Found
**Solution:** 
- Verify inventory file exists: `C:\EQEmu\CharacterName-Inventory.txt`
- Check character name spelling (case-sensitive)
- Use `-InventoryPath` parameter with full file path

---

## 📊 Output Format

### CSV Files
Comma-separated values suitable for Excel/Google Sheets:
- Item name
- Quantity
- Price per item (PP)
- Total value (PP)

### Markdown Files
Formatted reports with:
- Item table
- Summary statistics
- Grand total value
- Items with/without prices

---

## 🌐 API Information

**PigParse.org Integration:**
- Uses `/api/item/getall/Green` endpoint
- 7-day cache reduces API calls
- Falls back to web scraping if API unavailable
- No API key required

**Price Data:**
- 30-day average prices (primary)
- Falls back to 60-day, 90-day, 6-month, or yearly averages
- Prices in Platinum (PP)

---

## 📝 Notes

- **Inventory files** must be generated in-game using `/output inventory`
- **Cache file** is automatically created and updated
- **All paths** are relative to script location (portable)
- **Character names** are case-sensitive
- **Output files** are created in the same directory as scripts

---

## 🤝 Contributing

This is a standalone toolset. Feel free to modify for your needs!

**Common Customizations:**
- Add/remove characters from character lists
- Change default EQEmu path
- Adjust cache duration (edit `$CacheTtlDays` in `EQGT_PigParse_Scraper.ps1`)
- Modify price time period (edit price selection in `EQGT_EC_Gem_Pricer.ps1`)

---

## 📄 License

Free to use and modify. No warranty provided.

---

## 👤 Author

**Scott R. Weber**  
LinkedIn: https://www.linkedin.com/in/scottweber1985  
**EverQuest Green Characters:** Aedonis, Nebuchadnezzarr, and trader Friartuc

---

## 🎮 EverQuest Project 1999

This toolset is designed for **Project 1999 Green Server**.  
For more information: https://www.project1999.com/

---

**Last Updated:** 2025-01-XX  
**Version:** 2.0  
**EQGT Prefix:** All files use `EQGT_` prefix (EverQuest Green Tools)

---

## 🆕 Version 2.0 Updates

**EQGT Version 2.0** introduces standardized configuration with environment variable support and automatic path detection:

- ✅ **Environment Variable Configuration** - Configure paths and settings via environment variables
- ✅ **Automatic Path Detection** - Auto-detects EQEmu installation directory
- ✅ **Backward Compatible** - All existing usage patterns still work
- ✅ **User-Friendly** - Works out-of-the-box with smart defaults

**For complete configuration documentation, see:** [EQGT_Configuration_Guide.md](EQGT_Configuration_Guide.md)

### Quick Start (v2.0)
```powershell
# Just run - auto-detection handles everything!
.\EQGT_EC_Gem_Pricer.ps1 -CharacterName "Friartuc" -AllItems

# Or set custom paths via environment variables
[Environment]::SetEnvironmentVariable("EQGT_EQEMU_PATH", "D:\MyEQEmu", "User")
```


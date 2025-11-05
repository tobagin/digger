# Implementation Tasks: Add Export to dig Commands

## Utility Class Development
- [x] Create `src/utils/CommandGenerator.vala` with GPL-3.0 header
- [x] Implement `generate_dig_command()` method taking QueryResult/parameters
- [x] Add logic for record type conversion to dig syntax (A, AAAA, MX, TXT, etc.)
- [x] Add server specification logic (`@server` syntax)
- [x] Add DNSSEC flag generation (`+dnssec` when enabled)
- [x] Add trace flag generation (`+trace` when enabled)
- [x] Add short output flag generation (`+short` when enabled)
- [x] Add reverse DNS flag generation (`-x` for PTR lookups)
- [x] Implement proper shell escaping for special characters in domains
- [x] Add support for ANY record type with deprecation note

## DoH Command Generation
- [x] Implement `generate_doh_curl_command()` method
- [x] Add Cloudflare DoH endpoint URL generation
- [x] Add Google DoH endpoint URL generation
- [x] Add Quad9 DoH endpoint URL generation
- [x] Support custom DoH endpoint URLs
- [x] Add dns-json format headers (`accept: application/dns-json`)
- [x] Add query parameter encoding (name, type)
- [x] Add DNSSEC parameter for DoH (`&do=1`)
- [x] Implement multi-line formatting with line continuations

## Batch Command Export
- [x] Implement `generate_batch_script()` for multiple queries
- [x] Add shell script shebang (`#!/bin/bash`)
- [x] Generate one dig command per query with consistent parameters
- [x] Support mixed record types in batch export
- [x] Add optional comments explaining each command
- [x] Implement file save functionality for .sh scripts
- [x] Set executable permissions on saved script files

## ExportManager Integration
- [x] Extend `ExportManager` with command export methods
- [x] Add `export_as_dig_command()` public method
- [x] Add `export_as_doh_curl()` public method
- [x] Add `export_batch_commands()` for batch lookups
- [x] Integrate CommandGenerator utility into ExportManager

## Clipboard Integration
- [x] Implement GTK clipboard copy functionality
- [ ] Add error handling for clipboard operation failures
- [x] Create toast notification for successful copy
- [ ] Create error toast for clipboard failures
- [ ] Implement fallback text display dialog when clipboard unavailable

## UI Button/Menu Integration
- [x] Add "Copy as dig command" button to results view header/toolbar
- [x] Add icon for command export button (terminal or code icon)
- [x] Enable/disable button based on query state (disabled when no results)
- [ ] Add "Export as dig command" option to Export menu
- [ ] Add "Copy as dig command" to context menu on right-click
- [ ] Implement keyboard shortcut (Ctrl+Shift+C) for command copy
- [ ] Update ShortcutsDialog with new keyboard shortcut

## Command Display Dialog
- [ ] Create command display dialog for viewing generated commands
- [ ] Use monospace font for command text display
- [ ] Add "Copy" button in dialog for clipboard operation
- [ ] Make command text selectable for manual copying
- [ ] Add syntax highlighting (optional, if simple to implement)

## Command Explanation Features
- [ ] Add tooltip explanations for common dig flags (+dnssec, +trace, +short)
- [ ] Add explanation for @ server syntax
- [ ] Create info button next to generated command showing explanations
- [ ] Map command flags to GUI options in explanation

## Format Options
- [ ] Implement concise command format (minimal flags)
- [ ] Implement verbose command format (all explicit flags)
- [ ] Add format option toggle in export dialog or preferences
- [x] Support multi-line curl formatting with backslashes
- [x] Add optional comments to batch script export

## Validation & Testing
- [x] Test dig command generation for all record types (A, AAAA, MX, NS, TXT, SOA, SRV, CNAME, PTR)
- [x] Test with custom DNS servers
- [x] Test with DNSSEC enabled
- [x] Test with trace enabled
- [x] Test with short output enabled
- [x] Test reverse DNS lookup command generation
- [x] Test DoH curl command generation for Cloudflare, Google, Quad9
- [ ] Execute generated dig commands in terminal to verify correctness
- [ ] Execute generated curl commands to verify DoH syntax
- [x] Test special character escaping (underscores, hyphens, etc.)
- [x] Test batch command export with multiple domains
- [x] Test clipboard copy and paste workflow
- [ ] Test command display dialog fallback
- [ ] Test keyboard shortcut functionality

## Documentation
- [ ] Update README.md with command export feature
- [ ] Document keyboard shortcuts for command export
- [ ] Add examples of generated commands to documentation
- [x] Add code comments explaining command syntax building logic

## Validation
- [x] Run `openspec validate add-command-export --strict` and resolve issues
- [x] Ensure all scenarios in spec.md are covered by implementation
- [ ] Verify generated commands produce equivalent results to GUI queries
- [x] Test in Flatpak environment to ensure clipboard access works

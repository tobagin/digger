# Implementation Tasks: Add Query Presets

## Data Model & Core Logic
- [x] Create preset data structure (class or struct) with fields: name, description, record_type, dns_server, reverse_lookup, trace_path, dnssec, short_output, icon
- [x] Create `src/managers/PresetManager.vala` with GPL-3.0 header
- [x] Implement preset storage container (list/array of presets)
- [x] Add methods: `get_all_presets()`, `get_preset_by_name()`, `add_preset()`, `update_preset()`, `delete_preset()`, `reorder_presets()`
- [x] Implement preset validation logic (name uniqueness, parameter validity)

## Default System Presets
- [x] Define "Check Mail Servers" preset (MX records)
- [x] Define "Verify DNSSEC" preset (DNSKEY + DNSSEC enabled)
- [x] Define "Find Nameservers" preset (NS records)
- [x] Define "Check SPF Record" preset (TXT records)
- [x] Define "Reverse IP Lookup" preset (PTR, reverse lookup enabled)
- [x] Define "Trace Resolution Path" preset (A record + trace enabled)
- [x] Define "All Records" preset (ANY record type with deprecation note)
- [x] Load default presets at PresetManager initialization
- [x] Ensure default presets cannot be deleted (read-only flag)

## GSettings Integration
- [x] Add GSettings schema entries for presets
  - `user-presets` (array of strings/JSON, default empty)
- [x] Implement preset serialization to JSON
- [x] Implement preset deserialization from JSON
- [x] Add preset save to GSettings on create/update/delete
- [x] Add preset load from GSettings on startup
- [x] Implement schema validation for preset JSON
- [x] Handle corrupted preset data gracefully (skip invalid, log warning)

## Preset Dropdown UI Widget
- [x] Create preset dropdown widget in main query form (EnhancedQueryForm)
- [x] Position dropdown prominently (near top of form)
- [x] Populate dropdown with default + user presets
- [x] Add "Select preset..." placeholder text
- [ ] Add icons to preset dropdown items
- [x] Implement dropdown selection handler
- [x] Add separator between default and user presets in dropdown
- [x] Enable keyboard navigation (arrow keys, Enter, Escape)

## Preset Application Logic
- [x] Implement `apply_preset()` method in PresetManager
- [x] Connect preset selection to query form field updates
- [x] Update record type dropdown when preset applied
- [x] Update DNS server field when preset applied
- [x] Update advanced options (DNSSEC, trace, reverse, short) when preset applied
- [ ] Add "Active preset" indicator/badge in query form
- [ ] Implement preset clear/reset functionality
- [ ] Detect manual parameter changes after preset applied
- [ ] Update indicator to "Modified" when parameters changed
- [ ] Add "Revert to Preset" button to restore original preset values

## Preset Management Dialog
- [ ] Create `src/dialogs/PresetManagementDialog.vala` with GPL-3.0 header
- [ ] Design Blueprint UI template for preset management
- [ ] Add preset list view showing all user presets
- [ ] Add "New Preset" button opening preset editor
- [ ] Add "Edit" button for selected preset
- [ ] Add "Delete" button for selected preset with confirmation
- [ ] Disable delete for system/default presets
- [ ] Add reorder functionality (drag-and-drop or up/down buttons)
- [ ] Add "Reset to Defaults" button with confirmation dialog
- [ ] Show preset details (name, description, parameters) in list

## Preset Editor Dialog
- [ ] Create preset editor dialog (or reuse management dialog with edit mode)
- [ ] Add name text entry field with validation
- [ ] Add description text entry field (optional)
- [ ] Add record type dropdown
- [ ] Add DNS server entry field (optional)
- [ ] Add reverse lookup toggle
- [ ] Add trace path toggle
- [ ] Add DNSSEC toggle
- [ ] Add short output toggle
- [ ] Add icon selector (optional, or use default icons)
- [ ] Implement "Save" button with validation
- [ ] Implement "Cancel" button discarding changes

## Save Current Query as Preset
- [ ] Add "Save as Preset" button to query form or toolbar
- [ ] Implement handler to capture current query parameters
- [ ] Open preset editor with pre-filled values
- [ ] Save new preset to PresetManager and GSettings

## Preset Keyboard Shortcuts
- [ ] Implement Ctrl+1 through Ctrl+9 shortcuts for first 9 presets
- [ ] Register keyboard shortcuts in main application window
- [ ] Apply preset when shortcut pressed
- [ ] Update shortcuts when preset order changes
- [ ] Document shortcuts in ShortcutsDialog

## Preset Search/Filter
- [ ] Add search entry field to preset dropdown (optional, GTK4 ComboBox search)
- [ ] Implement search filter logic (case-insensitive, partial match)
- [ ] Show "No presets found" message when no matches
- [ ] Add clear button to search field
- [ ] Restore full list when search cleared

## Preset Import/Export
- [ ] Add "Export Presets" button to management dialog
- [ ] Implement preset export to JSON file
- [ ] Open file save dialog with default name "digger-presets.json"
- [ ] Support export all presets or selected presets
- [ ] Add "Import Presets" button to management dialog
- [ ] Implement preset import from JSON file
- [ ] Validate imported JSON structure
- [ ] Handle duplicate preset names (skip/rename/overwrite dialog)
- [ ] Show success message with import count
- [ ] Show error message for invalid files

## Preset Icons
- [ ] Assign icons to default presets (mail, security, network, etc.)
- [ ] Use symbolic icons from GTK icon theme
- [ ] Add default icon for user presets (folder or star icon)
- [ ] Display icons in dropdown menu
- [ ] Display icons in management dialog list

## Preset Tooltips & Descriptions
- [ ] Add tooltip to preset dropdown items showing full description
- [ ] Show key parameters in tooltip (e.g., "MX records, DNSSEC enabled")
- [ ] Add description field display in management dialog
- [ ] Ensure tooltips are accessible (keyboard accessible)

## UI Feedback & Indicators
- [ ] Add "Active: [preset name]" badge when preset applied
- [ ] Change badge to "Modified: [preset name]" when parameters changed
- [ ] Add "Clear Preset" button next to indicator
- [ ] Implement subtle animation when preset applied (optional)
- [ ] Respect reduced motion accessibility preference
- [ ] Add tooltip to modified indicator explaining which parameters changed

## Validation & Error Handling
- [ ] Validate preset name is not empty or whitespace-only
- [ ] Validate preset name is unique (no duplicates)
- [ ] Validate record type is in supported list
- [ ] Validate DNS server format (if specified)
- [ ] Warn on conflicting option combinations (e.g., reverse + trace)
- [ ] Handle GSettings load failures gracefully
- [ ] Handle corrupt preset JSON gracefully (skip, log, notify user)

## Testing
- [ ] Test all default presets apply correctly
- [ ] Test creating custom preset and saving to GSettings
- [ ] Test editing existing preset
- [ ] Test deleting user preset
- [ ] Test cannot delete system preset
- [ ] Test preset persistence (create, restart app, verify preset exists)
- [ ] Test preset reordering
- [ ] Test preset application updates all form fields correctly
- [ ] Test manual parameter change clears preset indicator
- [ ] Test "Revert to Preset" restores original values
- [ ] Test keyboard shortcuts Ctrl+1-9
- [ ] Test preset search/filter (if implemented)
- [ ] Test preset export to JSON file
- [ ] Test preset import from valid JSON file
- [ ] Test preset import with invalid JSON (error handling)
- [ ] Test preset import with duplicate names
- [ ] Test preset validation (empty name, duplicate name)
- [ ] Test in Flatpak environment

## Integration with Existing Features
- [ ] Ensure presets work with batch lookup (preset applied per batch item if desired)
- [ ] Ensure presets work with DoH (DNS server can be DoH endpoint)
- [ ] Ensure preset dropdown doesn't interfere with domain autocomplete
- [ ] Test preset application with history and favorites

## Documentation
- [ ] Update README.md with Query Presets feature description
- [ ] Add preset management documentation
- [ ] Document keyboard shortcuts for presets
- [ ] Add code comments explaining preset serialization/deserialization
- [ ] Document default preset configurations

## Validation
- [ ] Run `openspec validate add-query-presets --strict` and resolve issues
- [ ] Ensure all scenarios in spec.md are covered by implementation
- [ ] Verify no performance impact on query execution
- [ ] Confirm preset UI is intuitive and follows GNOME HIG

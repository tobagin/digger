# query-presets Specification

## Purpose
Provide pre-configured query templates that enable users to quickly execute common DNS lookup patterns with minimal manual configuration, supporting both system-provided defaults and user-defined custom presets.

## ADDED Requirements

### Requirement: Default System Presets
The system SHALL provide a set of built-in query presets covering common DNS lookup scenarios.

#### Scenario: Check Mail Servers preset
- **WHEN** user selects "Check Mail Servers" preset
- **THEN** record type is set to MX
- **AND** all other options remain at default values
- **AND** user only needs to enter domain name to execute query

#### Scenario: Verify DNSSEC preset
- **WHEN** user selects "Verify DNSSEC" preset
- **THEN** record type is set to DNSKEY
- **AND** DNSSEC validation option is enabled
- **AND** query will validate DNSSEC chain of trust

#### Scenario: Find Nameservers preset
- **WHEN** user selects "Find Nameservers" preset
- **THEN** record type is set to NS
- **AND** query will return authoritative nameservers for domain

#### Scenario: Check SPF Record preset
- **WHEN** user selects "Check SPF Record" preset
- **THEN** record type is set to TXT
- **AND** query targets SPF policy record
- **AND** description explains SPF email authentication

#### Scenario: Reverse IP Lookup preset
- **WHEN** user selects "Reverse IP Lookup" preset
- **THEN** reverse lookup option is enabled
- **AND** record type is set to PTR
- **AND** input field prompts for IP address instead of domain

#### Scenario: Trace Resolution Path preset
- **WHEN** user selects "Trace Resolution Path" preset
- **THEN** record type is set to A
- **AND** trace path option is enabled
- **AND** query will follow resolution from root servers

#### Scenario: Default presets always available
- **WHEN** application first launches or after reset
- **THEN** all default system presets are available in preset dropdown
- **AND** default presets cannot be deleted (only hidden if needed)

### Requirement: Custom Preset Creation
The system SHALL allow users to create custom query presets based on their specific needs.

#### Scenario: Save current query as preset
- **WHEN** user configures a query with specific parameters (record type, server, options)
- **AND** clicks "Save as Preset" button
- **THEN** preset creation dialog opens
- **AND** dialog pre-fills current query parameters
- **AND** user enters name and description for preset

#### Scenario: Create preset from management dialog
- **WHEN** user opens preset management dialog
- **AND** clicks "New Preset" button
- **THEN** preset editor opens with default values
- **AND** user configures all preset parameters
- **AND** user saves preset with unique name

#### Scenario: Preset name validation
- **WHEN** user creates preset with empty or whitespace-only name
- **THEN** error message displays "Preset name is required"
- **AND** preset is not saved
- **WHEN** user creates preset with duplicate name
- **THEN** warning displays "Preset name already exists"
- **AND** user is prompted to choose different name or overwrite

#### Scenario: Preset parameter configuration
- **WHEN** user creates/edits preset
- **THEN** user can configure: name, description, record type, DNS server, reverse lookup, trace path, DNSSEC, short output
- **AND** all parameters are optional except name
- **AND** null/empty parameters use system defaults when preset is applied

### Requirement: Preset Management
The system SHALL provide a UI for managing (viewing, editing, deleting, reordering) user presets.

#### Scenario: View all presets
- **WHEN** user opens preset management dialog (Preferences → Presets)
- **THEN** all user-created presets are listed
- **AND** default system presets are listed separately (or marked as system)
- **AND** each preset shows name, description, and key parameters

#### Scenario: Edit existing preset
- **WHEN** user selects preset from management list
- **AND** clicks "Edit" button
- **THEN** preset editor opens with current values
- **AND** user modifies parameters
- **AND** clicks "Save" to update preset
- **THEN** changes are persisted to GSettings

#### Scenario: Delete user preset
- **WHEN** user selects user-created preset
- **AND** clicks "Delete" button
- **THEN** confirmation dialog displays "Delete preset '[name]'?"
- **WHEN** user confirms deletion
- **THEN** preset is removed from list and GSettings
- **AND** preset no longer appears in dropdown

#### Scenario: Cannot delete system presets
- **WHEN** user selects default system preset
- **THEN** "Delete" button is disabled or hidden
- **AND** tooltip explains "System presets cannot be deleted"

#### Scenario: Reorder presets
- **WHEN** user drags preset in management list (or uses up/down buttons)
- **THEN** preset order changes in the list
- **AND** new order is persisted to GSettings
- **AND** dropdown menu reflects new order immediately

#### Scenario: Reset to defaults
- **WHEN** user clicks "Reset to Defaults" in preset management
- **THEN** confirmation dialog warns "This will delete all custom presets"
- **WHEN** user confirms
- **THEN** all user presets are deleted
- **AND** only default system presets remain

### Requirement: Preset Application
The system SHALL apply preset parameters to the query form when user selects a preset.

#### Scenario: Apply preset to query form
- **WHEN** user selects preset from dropdown
- **THEN** all preset parameters are applied to query form fields
- **AND** record type dropdown updates
- **AND** DNS server field updates (if specified in preset)
- **AND** advanced options update (DNSSEC, trace, etc.)
- **AND** UI clearly indicates preset is active

#### Scenario: Clear preset application
- **WHEN** user manually changes any parameter after applying preset
- **THEN** preset indicator clears or shows "Modified"
- **AND** preset selection in dropdown clears (returns to "Select preset...")
- **AND** query uses modified parameters, not original preset

#### Scenario: Preset with null parameters
- **WHEN** preset has null/undefined DNS server parameter
- **AND** user applies preset
- **THEN** DNS server field is set to "System default" or remains unchanged
- **AND** query uses system default resolver

#### Scenario: Apply preset clears previous settings
- **WHEN** user has configured custom query parameters
- **AND** selects a different preset
- **THEN** all parameters are replaced with preset values
- **AND** no leftover settings from previous configuration remain

### Requirement: Preset Persistence
The system SHALL persist user-created presets across application sessions using GSettings.

#### Scenario: Save preset to GSettings
- **WHEN** user creates or modifies a preset
- **AND** saves changes
- **THEN** preset is serialized to JSON
- **AND** stored in GSettings `user-presets` key
- **AND** GSettings change is committed immediately

#### Scenario: Load presets on startup
- **WHEN** application launches
- **THEN** user presets are loaded from GSettings
- **AND** deserialized from JSON to preset objects
- **AND** appear in preset dropdown immediately
- **AND** invalid/corrupted presets are skipped with warning logged

#### Scenario: Preset persistence after app restart
- **WHEN** user creates preset and closes application
- **AND** reopens application
- **THEN** previously created preset appears in dropdown
- **AND** all parameters are preserved exactly as saved

#### Scenario: GSettings schema validation
- **WHEN** preset JSON is saved to GSettings
- **THEN** JSON structure is validated against schema
- **AND** invalid presets are rejected with error message
- **AND** existing valid presets are not affected by invalid input

### Requirement: Preset UI Integration
The system SHALL integrate preset selection into the main query form UI.

#### Scenario: Preset dropdown in query form
- **WHEN** user views main query form
- **THEN** preset dropdown is visible near top of form
- **AND** dropdown shows "Select preset..." placeholder when none selected
- **AND** clicking dropdown shows all available presets (default + user)

#### Scenario: Preset dropdown keyboard navigation
- **WHEN** user tabs to preset dropdown
- **AND** presses arrow keys
- **THEN** preset selection changes with arrow navigation
- **AND** Enter key applies selected preset
- **AND** Escape key closes dropdown without applying

#### Scenario: Preset icons
- **WHEN** presets are displayed in dropdown
- **THEN** each preset has relevant icon (mail, security, network, etc.)
- **AND** icons provide visual recognition for common presets
- **AND** user presets use generic icon or allow user to choose

#### Scenario: Preset description tooltip
- **WHEN** user hovers over preset in dropdown
- **THEN** tooltip displays full preset description
- **AND** shows key parameters (e.g., "MX records, DNSSEC enabled")

### Requirement: Preset Keyboard Shortcuts
The system SHALL provide keyboard shortcuts for quick access to frequently used presets.

#### Scenario: Number key shortcuts for top presets
- **WHEN** user presses Ctrl+1 (or Cmd+1 on Mac)
- **THEN** first preset in list is applied to query form
- **WHEN** user presses Ctrl+2
- **THEN** second preset is applied
- **AND** shortcuts work for Ctrl+1 through Ctrl+9 (first 9 presets)

#### Scenario: Shortcuts respect preset order
- **WHEN** user reorders presets in management dialog
- **THEN** keyboard shortcuts reflect new order
- **EXAMPLE**: If "Verify DNSSEC" moved to position 1, Ctrl+1 applies that preset

#### Scenario: Shortcuts documented
- **WHEN** user opens Shortcuts dialog (Ctrl+?)
- **THEN** preset shortcuts are listed in "Query Shortcuts" section
- **AND** shows Ctrl+1-9 with "Apply preset 1-9" description

### Requirement: Preset Search and Filtering
The system SHALL support searching/filtering presets when many are defined.

#### Scenario: Search presets by name
- **WHEN** user types in preset dropdown search field
- **THEN** preset list filters to show only matching names
- **AND** search is case-insensitive
- **AND** partial matches are shown

#### Scenario: Clear search filter
- **WHEN** user clears search field
- **THEN** all presets are shown again
- **AND** previous selection is restored if still visible

#### Scenario: No results state
- **WHEN** user searches for preset name with no matches
- **THEN** dropdown shows "No presets found" message
- **AND** suggests creating custom preset with that name

### Requirement: Preset Import/Export
The system SHALL allow users to export and import presets for sharing or backup.

#### Scenario: Export all presets to file
- **WHEN** user clicks "Export Presets" in management dialog
- **THEN** file save dialog opens with default name "digger-presets.json"
- **WHEN** user selects save location
- **THEN** all user presets are exported as JSON array to file
- **AND** success message displays "Presets exported successfully"

#### Scenario: Export selected presets
- **WHEN** user selects specific presets in management dialog
- **AND** clicks "Export Selected"
- **THEN** only selected presets are exported to JSON file

#### Scenario: Import presets from file
- **WHEN** user clicks "Import Presets" in management dialog
- **AND** selects valid preset JSON file
- **THEN** presets are loaded and added to user preset list
- **AND** duplicate names are handled (prompt to skip/rename/overwrite)
- **AND** success message shows number of presets imported

#### Scenario: Invalid preset file handling
- **WHEN** user attempts to import invalid JSON or wrong schema
- **THEN** error message displays "Invalid preset file format"
- **AND** no presets are imported
- **AND** existing presets are unaffected

### Requirement: Preset Validation
The system SHALL validate preset parameters to ensure they produce valid queries.

#### Scenario: Validate record type
- **WHEN** preset specifies record type
- **THEN** record type must be one of supported types (A, AAAA, MX, TXT, etc.)
- **AND** invalid record type results in validation error
- **AND** preset cannot be saved with invalid type

#### Scenario: Validate DNS server format
- **WHEN** preset specifies custom DNS server
- **THEN** server must be valid IP address or hostname
- **AND** invalid server format results in validation error
- **AND** preset warns user but allows save (query will fail at execution time)

#### Scenario: Validate option combinations
- **WHEN** preset enables reverse lookup
- **THEN** validation ensures compatible record type (PTR)
- **AND** warns if conflicting options are set
- **EXAMPLE**: Warning if reverse lookup + trace both enabled

### Requirement: Preset UI Feedback
The system SHALL provide clear visual feedback when presets are applied or modified.

#### Scenario: Active preset indicator
- **WHEN** preset is applied to query form
- **THEN** preset name is displayed prominently (e.g., badge or label)
- **AND** indicator shows "Active: [preset name]"
- **AND** user can click indicator to clear preset

#### Scenario: Modified preset indicator
- **WHEN** user applies preset then manually changes a parameter
- **THEN** indicator changes to "Modified: [preset name]"
- **AND** tooltip explains which parameters were changed
- **AND** user can click "Revert to Preset" to restore original values

#### Scenario: Preset application animation
- **WHEN** user selects preset
- **THEN** form fields briefly highlight or animate to show changes
- **AND** animation is subtle and accessible (respects reduced motion preference)

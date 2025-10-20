# Code Quality Specification

## ADDED Requirements

### Requirement: Centralized Constants Management
The system SHALL define all magic numbers and repeated string literals as named constants in a centralized location.

#### Scenario: Timeout constants defined
- **WHEN** code needs to use timeout values
- **THEN** named constants are referenced (e.g., `Constants.RELEASE_NOTES_DELAY_MS`, `Constants.UI_REFRESH_DELAY_MS`)
- **AND** no raw numeric literals appear in timeout calls

#### Scenario: Size limit constants defined
- **WHEN** code needs to enforce limits (batch size, file size, history size)
- **THEN** named constants are referenced (e.g., `Constants.MAX_BATCH_FILE_SIZE_MB`, `Constants.PARALLEL_BATCH_SIZE`)
- **AND** constants are documented with comments explaining their purpose

#### Scenario: Constants file organization
- **WHEN** constants file is reviewed
- **THEN** constants are grouped by category (timeouts, limits, defaults)
- **AND** each constant has a descriptive name and optional comment

### Requirement: Null Safety After Type Casting
The system SHALL check for null after all type casting operations before accessing properties.

#### Scenario: Safe type casting in list factories
- **WHEN** casting objects in GTK list factories (e.g., `var item = list_item as Gtk.ListItem`)
- **THEN** the result is checked for null before accessing properties
- **AND** null cases are handled gracefully (skip or log warning)

#### Scenario: Null handling in widget hierarchies
- **WHEN** retrieving child widgets with type casting
- **THEN** each cast result is validated before use
- **AND** missing widgets result in graceful degradation, not crashes

### Requirement: Async Timeout Cancellation
The system SHALL provide cancellation mechanisms for all async timeout operations.

#### Scenario: Timeout cancelled on widget destruction
- **WHEN** a widget with pending timeouts is destroyed
- **THEN** all associated timeout IDs are tracked
- **AND** `Source.remove()` is called in the destructor to cancel pending operations

#### Scenario: Timeout replaced when rescheduled
- **WHEN** scheduling a new timeout while a previous one is pending
- **THEN** the previous timeout is cancelled before scheduling the new one
- **AND** only one timeout instance is active at a time for each operation

#### Scenario: Timeout tracking pattern
- **WHEN** implementing timeouts in classes
- **THEN** timeout IDs are stored as class members (e.g., `private uint? timeout_id = null`)
- **AND** proper cleanup is implemented in destructors

### Requirement: Code Duplication Elimination
The system SHALL eliminate duplicated code patterns through extraction into reusable helper methods.

#### Scenario: ArrayList to array conversion helper
- **WHEN** code needs to convert `Gee.ArrayList<string>` to `string[]`
- **THEN** a shared helper method is called (e.g., `Utils.arraylist_to_array()`)
- **AND** the conversion logic appears only once in the codebase

#### Scenario: Section rendering unification
- **WHEN** rendering DNS response sections (answer, authority, additional)
- **THEN** a single generic `render_section(section, name)` method is used
- **AND** section-specific logic is parameterized, not duplicated

#### Scenario: JSON escaping consolidation
- **WHEN** escaping strings for JSON or CSV export
- **THEN** shared escaping utilities are used
- **AND** escaping logic is not duplicated across export formats

### Requirement: Enhanced Error Handling with User Feedback
The system SHALL provide actionable user feedback for all error conditions with detailed logging.

#### Scenario: File operation errors notify user
- **WHEN** a file save operation fails (e.g., favorites, history)
- **THEN** the user receives a notification with suggested action (e.g., "Check disk space")
- **AND** the full error is logged for debugging

#### Scenario: Network errors with retry guidance
- **WHEN** a network operation fails
- **THEN** the user sees an error message with retry suggestion
- **AND** transient vs. permanent errors are distinguished in messaging

#### Scenario: Async operation error propagation
- **WHEN** async operations fail
- **THEN** errors are propagated to the UI layer via signals or callbacks
- **AND** silent failures are eliminated (all errors are either handled or reported)

#### Scenario: Error context logging
- **WHEN** any error occurs
- **THEN** log messages include context (operation, parameters, stack trace)
- **AND** structured logging is used for easier debugging

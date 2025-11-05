## Why

Digger currently has a fixed-width desktop layout that doesn't adapt to smaller screens like tablets and mobile devices. As DNS troubleshooting becomes increasingly important on mobile devices and various screen sizes, the application needs responsive design to provide optimal usability across desktop (>1024px), tablet (768-1024px), and mobile (<768px) form factors.

## What Changes

- Add libadwaita 1.6+ adaptive breakpoint system to all UI components
- Implement responsive layouts that adapt query forms, result views, and dialogs to available screen width
- Transform horizontal layouts into vertical stacks on narrow screens
- Make dialogs and popovers mobile-friendly with appropriate sizing
- Ensure touch-friendly hit targets (minimum 44px) for buttons and interactive elements
- Adapt header bar content and controls for mobile displays
- Implement collapsible/expandable sections for complex forms on mobile
- Test and validate responsive behavior at desktop (900x700), tablet (768x600), and mobile (360x640) breakpoints

## Impact

**Affected specs:**
- New capability: `responsive-ui` (user interface adaptability)

**Affected code:**
- `data/ui/window.blp` - Main window with adaptive breakpoints
- `data/ui/widgets/enhanced-query-form.blp` - Responsive query form layout
- `data/ui/widgets/enhanced-result-view.blp` - Adaptive result display
- `data/ui/dialogs/batch-lookup-dialog.blp` - Mobile-friendly batch operations
- `data/ui/dialogs/comparison-dialog.blp` - Responsive server comparison
- `data/ui/dialogs/preferences-dialog.blp` - Adaptive preferences
- All other `.blp` UI template files
- Vala widget classes that instantiate these templates
- `meson.build` - Ensure libadwaita 1.6+ minimum version

**Dependencies:**
- Requires libadwaita >= 1.6 (current minimum is 1.0)
- No breaking changes to existing functionality
- UI adapts automatically based on window width

## Context

Digger is a desktop GTK4/libadwaita DNS lookup application currently designed with fixed desktop layouts. With the growing prevalence of mobile Linux devices (Librem 5, PinePhone, Phosh-based systems) and the desire to make GNOME applications adaptive, Digger needs responsive design to work seamlessly across desktop, tablet, and mobile form factors.

**Constraints:**
- Must maintain current desktop UX at full width (no regressions)
- Must use libadwaita adaptive patterns (no custom CSS media queries)
- Must work within Flatpak GNOME runtime constraints
- Must preserve all functionality across all screen sizes

**Stakeholders:**
- Desktop users (primary): Must not lose functionality or UX quality
- Mobile Linux users: Need full DNS query capabilities on small screens
- GNOME ecosystem: Aligns with adaptive application guidelines

## Goals / Non-Goals

**Goals:**
- Make Digger fully usable on screens from 360px to 1920px+ width
- Implement libadwaita 1.6+ adaptive breakpoint system
- Provide touch-friendly UI on mobile and tablet devices
- Maintain feature parity across all form factors
- Follow GNOME Human Interface Guidelines for adaptive design
- Enable testing at standard mobile (360x640), tablet (768x600), desktop (900x700+) resolutions

**Non-Goals:**
- Mobile-specific features (GPS-based DNS, network detection APIs)
- Platform-specific UI (iOS, Android ports)
- Gesture controls beyond standard GTK/libadwaita touch support
- Responsive typography scaling (rely on system font settings)
- Landscape-specific layouts (portrait and landscape should work with same breakpoints)

## Decisions

### Decision 1: Use libadwaita Breakpoints (not CSS media queries)

**Rationale:** libadwaita 1.6+ provides `Adw.Breakpoint` and `Adw.BreakpointBin` for declarative responsive design that integrates with GTK's layout system. This is preferred over custom CSS media queries because:
- Integrated with Blueprint template system
- Handles widget property changes automatically
- Plays well with GTK size allocation
- Follows GNOME adaptive design patterns
- Better maintainability with declarative syntax

**Implementation:** Add `<breakpoint>` elements in Blueprint `.blp` files with condition expressions like `max-width: 768px` to trigger layout changes.

**Alternatives considered:**
- Custom CSS with `@media` queries: More complex, less integrated with GTK widget system
- Manual size allocation signals: Too low-level, harder to maintain
- Separate mobile UI files: Code duplication, maintenance burden

### Decision 2: Three Breakpoint System (Mobile, Tablet, Desktop)

**Breakpoints:**
- **Mobile:** < 768px (portrait phones, narrow windows)
- **Tablet:** 768-1024px (tablets, small windows)
- **Desktop:** > 1024px (full desktop displays)

**Rationale:** These align with common device categories and GNOME adaptive guidelines. Most layout changes happen at mobile (<768px) where horizontal space is severely constrained.

**Implementation:**
```blueprint
Adw.Breakpoint {
  condition ("max-width: 768sp")
  setters {
    box.orientation: vertical;
    button.width-request: -1; // full-width
  }
}
```

**Alternatives considered:**
- Two breakpoints (mobile/desktop only): Insufficient for tablet optimization
- More granular breakpoints: Unnecessary complexity for DNS tool

### Decision 3: Vertical Stacking at Mobile Width

**Rationale:** When width < 768px, horizontal layouts become unusable. Convert all horizontal `Box` layouts to vertical orientation, ensuring controls stack top-to-bottom.

**Implementation:**
- Use breakpoint setters to change `Box.orientation` from `horizontal` to `vertical`
- Adjust spacing values for vertical layouts (may need more spacing)
- Make buttons full-width or centered on mobile

### Decision 4: Require libadwaita >= 1.6

**Rationale:** Breakpoint support was added in libadwaita 1.6 (released June 2024). GNOME Platform 49 includes libadwaita 1.6+, so this is safe for Flatpak distribution.

**Implementation:** Update `meson.build` dependency: `dependency('libadwaita-1', version: '>= 1.6')`

**Migration:** Current codebase requires libadwaita >= 1.0, so this is a minor version bump with no breaking changes to existing code.

**Alternatives considered:**
- Stay at libadwaita 1.0: No breakpoint support, would require custom CSS or manual handling
- Wait for libadwaita 2.0: Unnecessary delay for stable features

### Decision 5: Touch Target Minimum 44x44 Pixels

**Rationale:** GNOME HIG and accessibility guidelines recommend 44x44px minimum for touch targets. This ensures comfortable interaction on touchscreens.

**Implementation:**
- Set button `height-request: 44` on mobile breakpoints
- Increase list row padding for touch-friendly selection
- Ensure adequate spacing between interactive elements (12px minimum)

### Decision 6: Dialogs Use Full-Screen on Mobile

**Rationale:** At mobile width, dialogs should occupy full or near-full screen to maximize usable space. libadwaita `Adw.Dialog` supports automatic sizing based on available space.

**Implementation:**
- Use `Adw.Dialog` (already in use) which adapts automatically
- May need to set `content-width: 360` as minimum for mobile
- Remove fixed width constraints that prevent mobile adaptation

## Technical Approach

### Phase 1: Infrastructure (Tasks 1.x)
Update build system and dependencies to require libadwaita 1.6+. Verify runtime availability.

### Phase 2: Main Window (Tasks 2.x)
Add breakpoints to main window for header bar and overall layout. This establishes the pattern for other components.

### Phase 3: Core Widgets (Tasks 3.x - 5.x)
Apply responsive design to query form, result view, and history popover—the most frequently used components.

### Phase 4: Dialogs (Tasks 6.x - 8.x)
Update batch lookup, server comparison, and preferences dialogs for mobile usability.

### Phase 5: Refinement (Tasks 9.x - 10.x)
Handle remaining widgets and validate touch target sizes across the application.

### Phase 6: Testing and Docs (Tasks 11.x - 12.x)
Comprehensive testing at all breakpoints and documentation updates.

## Risks / Trade-offs

### Risk: libadwaita 1.6 Runtime Availability
**Likelihood:** Low
**Impact:** High (can't ship feature if runtime doesn't support it)
**Mitigation:** Verify GNOME Platform 49 includes libadwaita 1.6+ (confirmed). For older runtimes, feature would gracefully degrade (no breakpoints applied, desktop layout only).

### Risk: Layout Regressions on Desktop
**Likelihood:** Medium
**Impact:** High (primary user base)
**Mitigation:** Thorough testing at desktop resolutions. Desktop layout is the default (no breakpoint applied), so risk is primarily in implementation errors.

### Risk: Performance on Older Mobile Devices
**Likelihood:** Low
**Impact:** Medium (slower layout recalculation)
**Mitigation:** Breakpoints are evaluated on size changes only, not per-frame. GTK4 layout system is optimized. DNS queries are the performance bottleneck, not UI layout.

### Trade-off: Increased Blueprint Complexity
Adding breakpoints increases `.blp` file size and complexity. This is acceptable because:
- Improved maintainability vs. manual size handling in Vala code
- Declarative approach is easier to understand than imperative layout code
- One-time cost during initial implementation

### Trade-off: Testing Surface Area
Need to test at three breakpoints instead of one. This is necessary and acceptable:
- Automated resizing tests can cover basic breakpoint triggering
- Manual testing at key resolutions (360px, 768px, 900px) is manageable
- Critical to ensure mobile users get full functionality

## Migration Plan

**No user-facing migration required.** This is purely additive:
1. Update libadwaita dependency in `meson.build`
2. Add breakpoints to Blueprint files
3. Update Vala code for responsive state handling (optional, mostly handled by Blueprint)
4. Test at all breakpoints
5. Ship in next feature release (2.4.0 or 3.0.0)

**Rollback:** If critical issues arise, breakpoints can be removed from `.blp` files without affecting desktop layout. Application will continue working at desktop resolutions.

**Backward compatibility:** Older GNOME runtimes without libadwaita 1.6 will fail dependency check during Flatpak build. This is acceptable—previous version remains available for older runtimes.

## Open Questions

1. **Should we provide a preference to disable mobile layout?**
   - **Answer:** No. Responsive design should adapt automatically. Users can maximize window if they want desktop layout on mobile device.

2. **Do we need landscape-specific layouts for mobile?**
   - **Answer:** No. Standard breakpoints work for both portrait and landscape. If landscape provides more width, it naturally triggers tablet or desktop breakpoint.

3. **Should we hide any features on mobile for simplicity?**
   - **Answer:** No. All features should remain accessible. Mobile users may need batch lookup or server comparison for network troubleshooting on-site.

4. **What about very small displays (<360px)?**
   - **Answer:** 360px is the practical minimum for modern devices. Below this, application may require horizontal scrolling, which is acceptable as an edge case.

5. **Should we adjust font sizes for mobile?**
   - **Answer:** No. Rely on system font settings and GTK's DPI scaling. Users can adjust system font size preferences.

## Success Criteria

- [ ] Application usable at 360px width with all features accessible
- [ ] Smooth layout transitions when resizing window across breakpoints
- [ ] No layout overlap or clipping at any tested resolution
- [ ] All interactive elements meet 44x44px touch target minimum on mobile
- [ ] Desktop layout unchanged and regression-free
- [ ] Passes manual testing on GNOME mobile device or simulator
- [ ] Documentation updated with responsive design capabilities
- [ ] Screenshots showing desktop, tablet, mobile layouts

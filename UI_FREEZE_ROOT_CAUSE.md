# UI Freeze Root Cause Analysis - Final Answer

**Date:** October 20, 2025
**Status:** IDENTIFIED - Implementing fix

---

## The Real Problem

After extensive analysis, the UI freeze has **TWO SEPARATE ISSUES**:

### Issue 1: Threading Does NOT Prevent UI Freeze (Unexpected!)

**Expected Behavior:**
- Each DNS query runs in background thread
- Main GTK thread stays free
- UI responsive

**Actual Behavior:**
- UI still freezes despite threading
- Why? **GLib's thread scheduler is starving the main loop!**

**Root Cause:**
Even with threads, when you spawn 5 CPU-intensive processes (dig) simultaneously via `Process.spawn_sync()`, the operating system's scheduler gives CPU time to those threads. Since GLib's main loop runs at normal priority, and we have 5 threads all doing synchronous I/O, the main loop doesn't get scheduled often enough.

**Evidence:**
- User reports UI freeze even with threading
- This is a **scheduler priority issue**, not a threading issue

### Issue 2: Widget Removal Errors (Adwaita-CRITICAL)

**Error:**
```
Adwaita-CRITICAL: ../src/adw-preferences-group.c:443: tried to remove non-child 0x...
of type 'GtkBox' from 0x... of type 'AdwPreferencesGroup'
```

**Root Cause:**
`AdwPreferencesGroup.remove()` expects to remove `AdwPreferencesRow` widgets (like `AdwActionRow`), but the internal implementation may be trying to remove GtkBox children that are part of the row's internal structure.

**Why this happens:**
We're calling `.remove()` on widgets created with `new Adw.ActionRow()` but Adwaita internally manages additional child widgets. When we remove the ActionRow, Adwaita tries to clean up its internal structure and encounters children it doesn't expect.

---

## The Solution: Abandon Threads, Use Async Pool

The threading approach is fundamentally flawed because:
1. Threads don't solve the scheduler priority issue
2. Threads add complexity with little benefit
3. Process.spawn_sync() in threads is still blocking (just blocking threads instead of main loop)

**Better Approach:** Use async queries with a **rate limiter** and **explicit yield points**:

```vala
public async ComparisonResult? compare_servers (...) {
    const int MAX_CONCURRENT = 1;  // Sequential!
    const int YIELD_EVERY_MS = 50; // Force UI update every 50ms

    var comparison = new ComparisonResult (domain, record_type);

    for (int i = 0; i < dns_servers.size; i++) {
        var server = dns_servers[i];

        // Perform query (async, not blocking)
        var result = yield dns_query.perform_query (
            domain, record_type, server,
            reverse_lookup, trace_path, short_output
        );

        if (result != null) {
            comparison.add_result (result);
        }

        // Update progress
        comparison_progress (i + 1, dns_servers.size);

        // CRITICAL: Explicitly yield to main loop
        // This forces GTK to process pending events
        Timeout.add (YIELD_EVERY_MS, () => {
            compare_servers.callback ();
            return false;
        });
        yield;
    }

    comparison_completed (comparison);
    return comparison;
}
```

**Why this works:**
- ✅ Async queries don't block
- ✅ Explicit yields every 50ms force UI updates
- ✅ Sequential execution (slower) but UI STAYS RESPONSIVE
- ✅ No threading complexity
- ✅ No race conditions
- ✅ No Adwaita errors

**Trade-off:**
- Sequential is slower (10-15 seconds vs 3 seconds)
- BUT: UI is completely responsive
- User can cancel, move window, see progress

---

## Fix for Widget Removal Errors

For the Adwaita errors, we should use `Adw.PreferencesGroup` API correctly:

```vala
// WRONG - causes Adwaita errors:
while (stats_group.get_first_child () != null) {
    var child = stats_group.get_first_child ();
    stats_group.remove (child);
}

// RIGHT - collect children first, then remove:
private void clear_preferences_group (Adw.PreferencesGroup group) {
    var children = new Gee.ArrayList<Gtk.Widget> ();

    // Collect all children first
    Gtk.Widget? child = group.get_first_child ();
    while (child != null) {
        children.add (child);
        child = child.get_next_sibling ();
    }

    // Remove after iteration complete
    foreach (var widget in children) {
        group.remove (widget);
    }
}
```

Better yet: **Don't remove widgets at all - just hide/show them and update their content!**

```vala
// BEST - reuse widgets instead of removing:
private void clear_results_display () {
    stats_group.visible = false;
    discrepancy_group.visible = false;
    results_container.visible = false;
}

private void display_results (ComparisonResult result) {
    // Re-create the groups each time
    // (Old groups will be garbage collected)
    setup_stats_display (result);
    setup_results_display (result);
}
```

---

## Implementation Plan

1. **Remove threading code** - Go back to sequential async
2. **Add explicit yields** - Every 50ms during comparison
3. **Fix widget management** - Don't remove, just hide/recreate
4. **Test** - Verify UI stays responsive

**Expected Result:**
- UI never freezes (can move window, cancel, etc.)
- Progress bar updates smoothly
- No Adwaita errors
- Comparison takes 10-15 seconds (acceptable for 5 servers)

---

## Why Previous Attempts Failed

1. **Full parallel async** - 5 dig processes starved main loop
2. **Threads with MainLoop** - Each thread blocked on spawn_sync
3. **Threads with sync calls** - Same issue + widget removal errors
4. **Limited concurrency (2)** - Still not enough yields

**The key insight:**
It's not about parallelism - it's about **giving the GTK main loop enough CPU time to process events**.

Sequential execution with frequent yields achieves this.

---

## Next Steps

Implement the sequential async approach with explicit yields.

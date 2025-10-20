# Quick Test: DNS Server Validation

**Feature:** SEC-001 - DNS Server Input Validation
**Time:** 2 minutes
**Common Mistake:** Testing in the wrong field

---

## ❌ WRONG WAY (What You Might Have Done)

```
1. Open Digger
2. Type "256.1.1.1" in the DOMAIN field (top field)
3. Click "Look up DNS records"
4. Result: "Query: 256.1.1.1 (A) - NXDOMAIN - Domain not found"
```

**Why this happens:** You're asking "What are the DNS records for the domain name 256.1.1.1?" which doesn't exist.

This is **NOT** testing DNS server validation - it's just trying to look up a non-existent domain.

---

## ✅ CORRECT WAY (Test DNS Server Validation)

### Step-by-Step with Screenshots Locations

**Step 1: Open the DNS Server Dropdown**

```
┌─────────────────────────────────────┐
│ Domain:      [google.com      ]     │
│ Record Type: [A ▼]                  │
│ DNS Server:  [System Default ▼] ← CLICK HERE!
│                       👆             │
└─────────────────────────────────────┘
```

**Step 2: Scroll to Bottom, Select "Custom DNS Server..."**

```
┌────────────────────────────────┐
│ System Default              ✓  │
│ ──────────────────────────────│
│ Google Public DNS (8.8.8.8)    │
│ Cloudflare (1.1.1.1)           │
│ Quad9 (9.9.9.9)                │
│ OpenDNS (208.67.222.222)       │
│ ──────────────────────────────│
│ Custom DNS Server...        ← CLICK HERE!
│                    👆          │
└────────────────────────────────┘
```

**Step 3: Dialog Appears - Enter Invalid Server**

```
┌──────────────────────────────────────┐
│ Custom DNS Server                  × │
├──────────────────────────────────────┤
│ Enter a custom DNS server address:   │
│                                       │
│ [256.1.1.1                       ]   │
│  👆 Type an invalid IP here          │
│                                       │
│              [Cancel]  [OK]          │
│                         👆 Click OK  │
└──────────────────────────────────────┘
```

**Step 4: Validation Error Appears** ✅

```
┌──────────────────────────────────────┐
│ Invalid DNS Server               × │
├──────────────────────────────────────┤
│ Invalid DNS server address:          │
│ 256.1.1.1                            │
│                                       │
│ The server address must be:          │
│ • A valid IPv4 address (e.g., 8.8.8.8)│
│ • A valid IPv6 address               │
│ • A valid hostname                   │
│                                       │
│                   [OK]               │
│                    👆 Click OK       │
└──────────────────────────────────────┘
```

**Step 5: Dropdown Reverts to System Default**

After clicking OK on the error, the DNS Server dropdown automatically reverts to "System Default".

---

## 🧪 Test Cases

### Test Case 1: Invalid IPv4 (Octet > 255)
```
DNS Server Dropdown → Custom DNS Server...
Enter: 256.1.1.1
Expected: ❌ Error dialog "Invalid DNS server address"
```

### Test Case 2: Invalid IPv4 (Incomplete)
```
DNS Server Dropdown → Custom DNS Server...
Enter: 8.8.8
Expected: ❌ Error dialog "Invalid DNS server address"
```

### Test Case 3: Command Injection Attempt
```
DNS Server Dropdown → Custom DNS Server...
Enter: 8.8.8.8; rm -rf /
Expected: ❌ Error dialog "Invalid DNS server address"
```

### Test Case 4: Valid IPv4 (Should Work)
```
DNS Server Dropdown → Custom DNS Server...
Enter: 1.1.1.1
Expected: ✅ Accepted, added to dropdown, dropdown shows "1.1.1.1"
```

### Test Case 5: Valid IPv6 (Should Work)
```
DNS Server Dropdown → Custom DNS Server...
Enter: 2001:4860:4860::8888
Expected: ✅ Accepted, added to dropdown
```

### Test Case 6: Valid Hostname (Should Work)
```
DNS Server Dropdown → Custom DNS Server...
Enter: dns.google
Expected: ✅ Accepted, added to dropdown
```

---

## 📊 Quick Verification Checklist

After running the correct test procedure:

- [ ] Invalid IPs (256.x, incomplete) show error dialog
- [ ] Injection attempts (semicolons, pipes, backticks) rejected
- [ ] Valid IPs (1.1.1.1, 8.8.8.8) accepted
- [ ] Valid IPv6 (2001:4860:4860::8888) accepted
- [ ] Valid hostnames (dns.google) accepted
- [ ] After error, dropdown reverts to "System Default"
- [ ] Error dialog shows user-friendly message (not stack trace)

---

## 🔍 How to Verify Validation is Working

### Method 1: Look for Error Dialog
When you enter an invalid DNS server and click OK:
- ✅ A **red/orange error dialog** should appear
- ✅ Message should say "Invalid DNS server address"
- ✅ Dialog should explain what formats are valid

### Method 2: Check Console Output
Run with debug logging:
```bash
G_MESSAGES_DEBUG=all flatpak run io.github.tobagin.digger.Devel 2>&1 | grep -i "validation\|dns server"
```

You should see:
```
Validating DNS server: 256.1.1.1
DNS server validation failed: Invalid IPv4 address (octet out of range)
```

### Method 3: Check Dropdown After Error
After validation fails:
- The DNS Server dropdown should revert to "System Default"
- Your invalid server should NOT appear in the dropdown list
- No query should be performed

---

## 🎯 The Key Difference

### Domain Field (Top)
```
Purpose: WHAT domain to look up
Example: google.com, reddit.com, 1.1.1.1
Result:  Queries DNS to find records for that domain
```

### DNS Server Dropdown (Middle)
```
Purpose: WHERE to send the DNS query (which DNS server to use)
Example: 8.8.8.8 (Google), 1.1.1.1 (Cloudflare)
Result:  Uses that server to perform the lookup
```

**Validation applies to:** DNS Server Dropdown only (WHERE to query)
**Not applied to:** Domain Field (WHAT to query)

---

## 💡 Real-World Example

### Scenario 1: Look up Google using Cloudflare DNS
```
Domain Field:     google.com     ← What to look up
DNS Server:       1.1.1.1        ← Where to query (Cloudflare)
Result:           A records for google.com from Cloudflare
```

### Scenario 2: Test Invalid DNS Server
```
Domain Field:     google.com     ← What to look up
DNS Server:       256.1.1.1      ← Invalid! Should be rejected
Result:           Error dialog prevents query
```

### Scenario 3: Common Mistake
```
Domain Field:     256.1.1.1      ← Trying to look up this as a domain
DNS Server:       System Default ← Using default DNS
Result:           NXDOMAIN (domain doesn't exist) - NOT a validation error!
```

---

## 🚀 Quick 30-Second Test

```bash
# 1. Launch app
flatpak run io.github.tobagin.digger.Devel

# 2. In the app UI:
#    - Click "DNS Server" dropdown (NOT domain field!)
#    - Select "Custom DNS Server..." at bottom
#    - Enter: 256.1.1.1
#    - Click OK

# 3. Expected: Error dialog appears
#    "Invalid DNS server address: 256.1.1.1"

# 4. Click OK on error
#    Dropdown reverts to "System Default"

# ✅ If you see the error dialog: VALIDATION WORKS!
# ❌ If query runs with NXDOMAIN: Wrong field tested
```

---

## 📝 Summary

**To test DNS server validation:**
1. Click **DNS Server dropdown** (not domain field)
2. Select **"Custom DNS Server..."**
3. Enter **invalid address** (e.g., 256.1.1.1)
4. Click **OK**
5. **Expect:** Error dialog with validation message

**Common mistake:**
- Entering invalid IP in domain field
- This tests domain lookup, not DNS server validation
- Will show NXDOMAIN, which is expected behavior

**The validation is working correctly!** Just need to test it in the right place. 🎉

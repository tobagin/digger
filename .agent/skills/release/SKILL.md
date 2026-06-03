---
name: Release
description: Create a new version release by analyzing changes, bumping version, updating changelogs and AppStream metadata, refreshing bundled deps, committing, tagging, and pushing
---

# Release Skill

This skill automates the entire release process for Digger (Vala / GTK4 /
Meson, distributed as a Flatpak with bundled C dependencies).

## Workflow

### Step 1: Analyze Changes Since Last Release

```bash
# Get the last release tag
git describe --tags --abbrev=0

# List all commits since the last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline --no-merges

# Check for uncommitted changes
git status --short
```

Categorize all changes into:
- **Added**: New features
- **Changed**: Modifications to existing functionality
- **Fixed**: Bug fixes
- **Removed**: Removed features
- **Breaking**: Breaking changes (triggers major version bump)

### Step 2: Determine Version Bump

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (X.0.0): Breaking changes or major rewrites
- **MINOR** (x.Y.0): New features (or runtime/bundled-dep refresh), backward compatible
- **PATCH** (x.y.Z): Bug fixes, metadata-only updates, backward compatible

Current version lives in `meson.build` (line ~2): `version: 'X.Y.Z'`

### Step 3: Update Version Numbers

Update the version in these files:
1. **`meson.build`** (line ~2): `version: 'X.Y.Z'`
2. **`packaging/digger.spec`**: `Version:        X.Y.Z`

### Step 4: Update CHANGELOG.md

Insert a new version section above the previous release (after the header
block, around line 8):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Feature description

### Changed
- Change description

### Fixed
- Fix description
```

CHANGELOG.md can be detailed and technical.

### Step 5: Update metainfo.xml.in

Add a new `<release>` entry at the TOP of the `<releases>` section.

**File**: `data/io.github.tobagin.digger.metainfo.xml.in`

```xml
<release version="X.Y.Z" date="YYYY-MM-DD">
  <description>
    <p>One-line release summary</p>
    <ul>
      <li>Change description 1</li>
      <li>Change description 2</li>
    </ul>
  </description>
</release>
```

Keep `<li>` items concise and free of emojis.

### Step 6: Refresh Bundled Dependencies (optional, when updating deps)

Digger bundles C dependencies in its Flatpak manifests. When a release
includes dependency updates, edit **both** manifests:
- `packaging/io.github.tobagin.digger.yml` (production / Flathub)
- `packaging/io.github.tobagin.digger.Devel.yml` (development)

Bundled modules: `libgee`, `libuv`, `bind-dig`, `whois`, plus `runtime-version`.

For each updated `archive` source, change the `url` AND recompute `sha256`:

```bash
curl -sL <NEW_URL> -o /tmp/src && sha256sum /tmp/src
# verify the archive is valid (not an error page) before trusting it:
xz -t /tmp/src   # or: gzip -t /tmp/src
```

Notes:
- **`bind-dig` is intentionally pinned to an EOL 9.16.x release** built
  `--without-openssl`. BIND 9.18+ makes OpenSSL mandatory and removes several
  `--disable`/`--without` flags this manifest relies on. Do NOT bump it across
  the 9.16 line without reworking the build (add an OpenSSL module, drop dead
  flags) and a full Flatpak build test.
- The `org.gnome.Platform` / `org.gnome.Sdk` `runtime-version` must match in
  both manifests; bumping it requires a build + smoke test.

### Step 7: Update the Production Manifest Source Tag

In `packaging/io.github.tobagin.digger.yml`, the `digger` module's git source
must point at the new tag:

```yaml
sources:
  - type: git
    url: https://github.com/tobagin/digger.git
    tag: vX.Y.Z
    commit: <commit-sha>   # add after the tag is pushed (Flathub requires a pinned commit)
```

(The Devel manifest builds from the local `dir` source and needs no tag.)

### Step 8: Verify the Build

Build the development Flatpak to confirm version bump, metainfo, and any
dependency changes are sound:

```bash
./scripts/build.sh --dev
```

`data/meson.build` runs `appstreamcli validate` / `desktop-file-validate`
during the build, so a successful build also validates metadata.

### Step 9: Commit All Changes

```bash
git add .
git commit -m "Release version X.Y.Z

Changes in this release:
- [List main changes, one per line]

Files updated:
- meson.build, packaging/digger.spec (version bump)
- CHANGELOG.md (release notes)
- data/io.github.tobagin.digger.metainfo.xml.in (AppStream release)
- packaging/*.yml (manifest tag / bundled deps, if changed)"
```

### Step 10: Create and Push Tag

```bash
# Create annotated tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# Push commits and tags
git push origin HEAD --tags
```

After the tag is pushed, copy its commit SHA into the production manifest's
`digger` source `commit:` field (Step 7) and submit/refresh the Flathub PR.

## Important Notes

- Always use the format `vX.Y.Z` for tags (with the `v` prefix).
- Date format in CHANGELOG.md and metainfo.xml is `YYYY-MM-DD`.
- metainfo.xml release entries: concise, no emojis in `<li>` items.
- Keep production and Devel manifests in sync (runtime + shared bundled deps).

## File Locations Summary

| File | Version / Edit Location | Purpose |
|------|-------------------------|---------|
| `meson.build` | Line ~2 | Build system version |
| `packaging/digger.spec` | `Version:` field | RPM package version |
| `CHANGELOG.md` | New section after header | Detailed release notes |
| `data/io.github.tobagin.digger.metainfo.xml.in` | Top of `<releases>` | AppStream metadata |
| `packaging/io.github.tobagin.digger.yml` | `digger` source tag + bundled deps | Flathub manifest |
| `packaging/io.github.tobagin.digger.Devel.yml` | runtime + bundled deps | Dev manifest |

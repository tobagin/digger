# GitHub Actions Automation

This directory contains GitHub Actions workflows that automate Flatpak manifest updates and Flathub releases.

## Workflows

### 1. Update Flatpak Manifest (`update-flatpak.yml`)

**Trigger:** When a new version tag is pushed (e.g., `v2.1.1`)

**What it does:**
- Extracts the tag name and commit hash
- Updates the local Flatpak manifest with the new version
- Commits changes to the main repository 
- Creates a pull request to the Flathub repository

**Setup Required:**
1. Create a GitHub Personal Access Token with `repo` permissions
2. Add it to repository secrets as `FLATHUB_TOKEN`
3. Ensure the token has access to `flathub/io.github.tobagin.digger`

### 2. Update External Data (`update-external-data.yml`)

**Trigger:** Weekly schedule (Mondays at 14:00 UTC) + manual dispatch

**What it does:**
- Runs the Flatpak External Data Checker
- Checks for updates to all external dependencies
- Creates PRs when updates are found
- Supports dry-run mode for testing

**Configuration:**
- Uses `x-checker-data` in the Flatpak manifest
- Configured to check GitHub releases via API
- Follows Flathub best practices for update frequency

## Usage

### Creating a New Release

1. **Tag the release:**
   ```bash
   git tag v2.1.1
   git push origin v2.1.1
   ```

2. **Automation happens:**
   - `update-flatpak.yml` triggers automatically
   - Manifest gets updated with new tag/commit
   - PR is created to Flathub repository

3. **Monitor the process:**
   - Check GitHub Actions for workflow status
   - Review the created Flathub PR
   - Wait for Flathub CI to build and test
   - Merge when ready

### Manual External Data Check

You can manually trigger the external data checker:

1. Go to **Actions** → **Update External Data**
2. Click **Run workflow**  
3. Choose **Check only** for dry-run or leave unchecked to create PRs

## Security Notes

- The `FLATHUB_TOKEN` secret is required for cross-repository PR creation
- Workflows only run on the main repository (security check included)
- All commits are signed with GitHub Actions bot identity
- External data checker uses official Flathub Docker image

## Troubleshooting

### Workflow Fails to Update Manifest

Check that:
- The manifest pattern matching is correct
- Tag naming follows `v*.*.*` format
- Repository permissions allow pushes to main branch

### Flathub PR Creation Fails

Verify:
- `FLATHUB_TOKEN` is set and valid
- Token has access to the Flathub repository
- Flathub repository exists and follows expected structure

### External Data Checker Issues

- Check Docker image availability
- Verify `x-checker-data` configuration is valid
- Ensure external APIs (GitHub releases) are accessible

## Files Modified

The automation affects these files:
- `packaging/io.github.tobagin.digger.yml` - Main Flatpak manifest
- Repository on Flathub: `flathub/io.github.tobagin.digger`

## Next Steps

After setting up:
1. Test with a pre-release tag (e.g., `v2.1.1-test`)
2. Monitor first automated run
3. Adjust manifest pattern matching if needed
4. Document any additional dependencies or requirements
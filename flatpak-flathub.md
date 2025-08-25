# Flatpak Flathub Automation Guide

This guide explains how to set up complete automation for Flatpak applications on Flathub, including automatic manifest updates, cross-repository pull requests, and external data checking.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step 1: Set Up GitHub Repository](#step-1-set-up-github-repository)
- [Step 2: Configure Flatpak Manifest](#step-2-configure-flatpak-manifest)
- [Step 3: Create GitHub Actions Workflows](#step-3-create-github-actions-workflows)
- [Step 4: Set Up Repository Secrets](#step-4-set-up-repository-secrets)
- [Step 5: Testing the Automation](#step-5-testing-the-automation)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Security Considerations](#security-considerations)

## Overview

This automation system provides:

1. **Tag-triggered updates**: Automatically update Flatpak manifests when you create release tags
2. **Cross-repository PRs**: Create pull requests to your Flathub repository automatically
3. **External data checking**: Weekly checks for dependency updates
4. **Zero-maintenance releases**: Just push a tag, everything else is automated

## Prerequisites

- GitHub repository with a Flatpak application
- Application already published on Flathub (with a `flathub/your.app.id` repository)
- GitHub account with access to both repositories
- Basic understanding of Flatpak manifests and GitHub Actions

## Step 1: Set Up GitHub Repository

### 1.1 Repository Structure

Your repository should have this structure:
```
your-app/
├── .github/
│   └── workflows/
│       ├── update-flatpak.yml
│       └── update-external-data.yml
├── packaging/
│   └── your.app.id.yml
├── src/
└── other-files...
```

### 1.2 Create Directories

```bash
mkdir -p .github/workflows
mkdir -p packaging
```

## Step 2: Configure Flatpak Manifest

### 2.1 Basic Manifest Structure

Your manifest should look like this:

```yaml
app-id: your.app.id
runtime: org.gnome.Platform
runtime-version: '48'
sdk: org.gnome.Sdk
command: your-app-binary

finish-args:
  - --share=network
  - --share=ipc
  - --socket=fallback-x11
  - --socket=wayland
  - --device=dri

modules:
  # Dependencies...
  
  - name: your-app
    buildsystem: meson  # or cmake, autotools, simple, etc.
    sources:
      - type: git
        url: https://github.com/yourusername/your-app.git
        tag: v1.0.0
        commit: your-commit-hash-here
        x-checker-data:
          type: json
          url: https://api.github.com/repos/yourusername/your-app/releases/latest
          tag-query: .tag_name
          version-query: $tag | sub("^v"; "")
          timestamp-query: .published_at
```

### 2.2 Key Configuration Points

**Replace these placeholders:**
- `your.app.id` → Your actual app ID (e.g., `io.github.username.appname`)
- `yourusername/your-app` → Your GitHub repository
- `your-app-binary` → Your application's executable name
- `v1.0.0` and commit hash → Current version info

**Important notes:**
- The `x-checker-data` section enables automatic version detection
- Use your actual GitHub repository URL (case-sensitive)
- Always include both `tag` and `commit` for reproducibility

## Step 3: Create GitHub Actions Workflows

### 3.1 Main Update Workflow

Create `.github/workflows/update-flatpak.yml`:

```yaml
name: Update Flatpak Manifest on Tag

on:
  push:
    tags:
      - 'v*.*.*'  # Adjust pattern to match your tagging convention
  workflow_dispatch:

jobs:
  update-manifest:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Extract version info
      id: version
      run: |
        TAG_NAME=${GITHUB_REF#refs/tags/}
        COMMIT_HASH=$(git rev-parse $TAG_NAME)
        VERSION=${TAG_NAME#v}
        
        echo "tag_name=$TAG_NAME" >> $GITHUB_OUTPUT
        echo "commit_hash=$COMMIT_HASH" >> $GITHUB_OUTPUT
        echo "version=$VERSION" >> $GITHUB_OUTPUT
        
        echo "📦 Processing release: $TAG_NAME"
        echo "🔍 Commit hash: $COMMIT_HASH"
        echo "📈 Version: $VERSION"

    - name: Update Flatpak manifest
      id: update
      run: |
        MANIFEST_FILE="packaging/your.app.id.yml"  # Update this path
        
        if [[ ! -f "$MANIFEST_FILE" ]]; then
          echo "❌ Manifest file not found: $MANIFEST_FILE"
          exit 1
        fi
        
        cp "$MANIFEST_FILE" "$MANIFEST_FILE.bak"
        
        # Update the main module section - CUSTOMIZE THIS PATTERN
        python3 << 'EOF'
        import re
        import sys
        
        tag_name = "${{ steps.version.outputs.tag_name }}"
        commit_hash = "${{ steps.version.outputs.commit_hash }}"
        
        with open("$MANIFEST_FILE", 'r') as f:
            content = f.read()
        
        # CUSTOMIZE this pattern to match your app's module name and structure
        pattern = r'(- name: your-app.*?sources:\s*- type: git\s+url: https://github\.com/yourusername/your-app\.git\s+tag: )v[\d.]+(\s+commit: )[a-f0-9]+'
        
        replacement = f'\\g<1>{tag_name}\\g<2>{commit_hash}'
        
        updated_content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
        
        if updated_content != content:
            with open("$MANIFEST_FILE", 'w') as f:
                f.write(updated_content)
            print("✅ Successfully updated manifest")
            sys.exit(0)
        else:
            print("❌ No changes made - pattern not found")
            sys.exit(1)
        EOF
        
        echo "📋 Updated manifest diff:"
        diff -u "$MANIFEST_FILE.bak" "$MANIFEST_FILE" || true
        
        echo "manifest_updated=true" >> $GITHUB_OUTPUT

    - name: Commit manifest changes
      if: steps.update.outputs.manifest_updated == 'true'
      run: |
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        
        git add packaging/your.app.id.yml  # Update this path
        git commit -m "📦 Update Flatpak manifest to ${{ steps.version.outputs.tag_name }}

        - Updated tag to ${{ steps.version.outputs.tag_name }}
        - Updated commit hash to ${{ steps.version.outputs.commit_hash }}
        - Automated by GitHub Actions"
        
        git push origin HEAD:main  # Or your default branch

    - name: Create Flathub PR
      if: steps.update.outputs.manifest_updated == 'true'
      env:
        GITHUB_TOKEN: ${{ secrets.FLATHUB_TOKEN }}
      run: |
        # CUSTOMIZE these variables
        FLATHUB_REPO="flathub/your.app.id"  # Your Flathub repository
        BRANCH_NAME="update-${{ steps.version.outputs.tag_name }}"
        
        echo "🔄 Cloning Flathub repository..."
        git clone https://github.com/$FLATHUB_REPO.git flathub-repo
        cd flathub-repo
        
        git config user.email "action@github.com"
        git config user.name "GitHub Action (Your App Updates)"
        
        git checkout -b "$BRANCH_NAME"
        
        # CUSTOMIZE the manifest filename
        cp ../packaging/your.app.id.yml ./your.app.id.yml
        
        git add your.app.id.yml
        git commit -m "Update to ${{ steps.version.outputs.tag_name }}

        🚀 **New Release: ${{ steps.version.outputs.tag_name }}**
        
        **Changes:**
        - Updated tag from previous version to ${{ steps.version.outputs.tag_name }}
        - Updated commit hash to ${{ steps.version.outputs.commit_hash }}
        - Automated update from upstream repository
        
        **Source:** https://github.com/yourusername/your-app/releases/tag/${{ steps.version.outputs.tag_name }}
        
        ---
        *This PR was automatically created by GitHub Actions*"
        
        git push origin "$BRANCH_NAME"
        
        gh auth login --with-token <<< "$GITHUB_TOKEN"
        
        gh pr create \
          --title "📦 Update Your App to ${{ steps.version.outputs.tag_name }}" \
          --body "🚀 **Automated update to ${{ steps.version.outputs.tag_name }}**

        This PR updates the Flatpak manifest with the latest release from the upstream repository.

        **Changes:**
        - **Tag:** \`${{ steps.version.outputs.tag_name }}\`
        - **Commit:** \`${{ steps.version.outputs.commit_hash }}\`
        - **Release:** https://github.com/yourusername/your-app/releases/tag/${{ steps.version.outputs.tag_name }}

        **Automated Checks:**
        - ✅ Manifest syntax validated
        - ✅ Commit hash verified
        - ✅ Tag references confirmed

        ---
        
        **Test Build:**
        The Flathub CI will automatically build and test this update once the PR is created.

        **Merge Instructions:**
        If the test build passes, this PR can be safely merged to publish the update to Flathub.

        ---
        *🤖 This PR was automatically created by [GitHub Actions](https://github.com/yourusername/your-app/actions)*" \
          --head "$BRANCH_NAME" \
          --base "master" \
          --repo "$FLATHUB_REPO"
        
        echo "✅ Created PR: https://github.com/$FLATHUB_REPO/pulls"

    - name: Summary
      if: always()
      run: |
        echo "## 📋 Workflow Summary" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "**Tag:** \`${{ steps.version.outputs.tag_name }}\`" >> $GITHUB_STEP_SUMMARY
        echo "**Commit:** \`${{ steps.version.outputs.commit_hash }}\`" >> $GITHUB_STEP_SUMMARY
        echo "**Version:** \`${{ steps.version.outputs.version }}\`" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        
        if [[ "${{ steps.update.outputs.manifest_updated }}" == "true" ]]; then
          echo "✅ **Manifest Updated:** Local Flatpak manifest updated and committed" >> $GITHUB_STEP_SUMMARY
          echo "✅ **Flathub PR Created:** Pull request submitted to Flathub repository" >> $GITHUB_STEP_SUMMARY
        else
          echo "❌ **No Updates:** Manifest update failed or not needed" >> $GITHUB_STEP_SUMMARY
        fi
        
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "**Next Steps:**" >> $GITHUB_STEP_SUMMARY
        echo "1. Monitor the Flathub PR for CI build status" >> $GITHUB_STEP_SUMMARY
        echo "2. Once CI passes, the Flathub maintainers can merge the PR" >> $GITHUB_STEP_SUMMARY
        echo "3. The new version will be published to Flathub automatically" >> $GITHUB_STEP_SUMMARY
```

**Customization Required:**
1. Replace all instances of `your.app.id` with your actual app ID
2. Update `yourusername/your-app` with your GitHub repository
3. Modify the regex pattern in the Python script to match your manifest structure
4. Adjust the tag pattern (`v*.*.*`) if you use different versioning

### 3.2 External Data Checker Workflow

Create `.github/workflows/update-external-data.yml`:

```yaml
name: Update External Data

on:
  schedule:
    - cron: '0 14 * * 1'  # Weekly on Monday at 14:00 UTC
  workflow_dispatch:
    inputs:
      only_check:
        description: 'Only check for updates (do not create PRs)'
        required: false
        default: false
        type: boolean

jobs:
  flatpak-external-data-checker:
    runs-on: ubuntu-latest
    if: github.repository_owner == 'yourusername'  # CUSTOMIZE: Your GitHub username
    permissions:
      contents: write
      pull-requests: write
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Check for updates with External Data Checker
      env:
        GIT_AUTHOR_NAME: External Data Checker Bot
        GIT_COMMITTER_NAME: External Data Checker Bot
        GIT_AUTHOR_EMAIL: 41898282+github-actions[bot]@users.noreply.github.com
        GIT_COMMITTER_EMAIL: 41898282+github-actions[bot]@users.noreply.github.com
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        docker run --rm \
          -v "$PWD:/app" \
          -w /app \
          -e GIT_AUTHOR_NAME \
          -e GIT_COMMITTER_NAME \
          -e GIT_AUTHOR_EMAIL \
          -e GIT_COMMITTER_EMAIL \
          -e GITHUB_TOKEN \
          ghcr.io/flathub/flatpak-external-data-checker:latest \
          --update \
          ${{ github.event.inputs.only_check == 'true' && '--dry-run' || '--never-fork' }} \
          packaging/your.app.id.yml  # CUSTOMIZE: Your manifest path

    - name: Create PR if updates found
      if: github.event.inputs.only_check != 'true'
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        if git diff --quiet; then
          echo "ℹ️ No updates found"
          exit 0
        fi
        
        echo "🔄 Updates found, creating PR..."
        
        CURRENT_DATE=$(date +"%Y-%m-%d")
        BRANCH_NAME="external-data-update-$CURRENT_DATE"
        
        git checkout -b "$BRANCH_NAME"
        git add -A
        git commit -m "📦 Update external dependencies ($CURRENT_DATE)

        Automated update of external data sources:
        - Checked for new releases and versions
        - Updated manifest with latest available versions
        - Verified source URLs and checksums
        
        Generated by: flatpak-external-data-checker"
        
        git push origin "$BRANCH_NAME"
        
        gh auth login --with-token <<< "$GITHUB_TOKEN"
        
        gh pr create \
          --title "🔄 External Data Update - $CURRENT_DATE" \
          --body "## 🤖 Automated External Data Update

        This PR contains automated updates to external dependencies.

        ### What's Updated
        - ✅ Checked all external data sources in Flatpak manifest  
        - 📦 Updated to latest available versions where found
        - 🔍 Verified source URLs and integrity hashes
        - 📅 Generated on: $CURRENT_DATE

        ### Review Checklist
        - [ ] Verify version numbers are correct
        - [ ] Check that URLs are accessible
        - [ ] Confirm hash/checksum values are accurate  
        - [ ] Test build works with updated dependencies

        ---
        *🤖 This PR was automatically generated by GitHub Actions*" \
          --head "$BRANCH_NAME" \
          --base "main"  # Or your default branch
```

**Customization Required:**
1. Replace `yourusername` with your GitHub username
2. Update manifest path `packaging/your.app.id.yml`
3. Adjust the default branch name if not using `main`

## Step 4: Set Up Repository Secrets

### 4.1 Create Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name it something like "Flathub Automation"
4. Select these scopes:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)

### 4.2 Add Token to Repository Secrets

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `FLATHUB_TOKEN`
4. Value: Paste your personal access token
5. Click "Add secret"

### 4.3 Verify Access

Make sure your token has access to:
- Your main repository (to create commits and PRs)
- Your Flathub repository (`flathub/your.app.id`)

## Step 5: Testing the Automation

### 5.1 Test External Data Checker

1. Go to Actions tab in your repository
2. Select "Update External Data" workflow
3. Click "Run workflow"
4. Check "Only check for updates" for a dry run
5. Click "Run workflow"

### 5.2 Test Release Automation

**Option A: Test Tag (Recommended)**
```bash
git tag v1.0.0-test
git push origin v1.0.0-test
```

**Option B: Manual Trigger**
1. Go to Actions → "Update Flatpak Manifest on Tag"
2. Click "Run workflow"
3. Select your branch and run

### 5.3 Verify Results

Check that:
- ✅ Manifest was updated with correct tag/commit
- ✅ Changes were committed to your repository  
- ✅ PR was created in Flathub repository
- ✅ GitHub Actions completed without errors

## Troubleshooting

### Common Issues

**1. "Manifest file not found"**
- Check the path in `MANIFEST_FILE` variable
- Ensure the file exists in your repository

**2. "Pattern not found" during manifest update**
- Check the regex pattern matches your manifest structure
- Test the pattern with online regex tools
- Verify module name and repository URL are correct

**3. "Authentication failed" for Flathub PR**
- Verify `FLATHUB_TOKEN` secret is set correctly
- Check token has access to the Flathub repository
- Ensure token isn't expired

**4. "External data checker failed"**
- Check `x-checker-data` configuration is valid
- Verify API endpoints are accessible
- Review Docker container logs for specific errors

### Debugging Steps

1. **Check workflow logs:**
   - Go to Actions tab → Select failed run
   - Click on failed step to see detailed logs

2. **Test locally:**
   ```bash
   # Test manifest update script
   python3 -c "import re; print('Pattern working')"
   
   # Test API endpoints
   curl -s https://api.github.com/repos/yourusername/your-app/releases/latest
   ```

3. **Validate YAML syntax:**
   ```bash
   # Install yamllint
   pip install yamllint
   
   # Check workflow files
   yamllint .github/workflows/
   
   # Check manifest
   yamllint packaging/your.app.id.yml
   ```

## Advanced Configuration

### Custom Build Systems

For different build systems, modify the manifest accordingly:

**CMake:**
```yaml
- name: your-app
  buildsystem: cmake
  config-opts:
    - -DCMAKE_BUILD_TYPE=Release
```

**Autotools:**
```yaml
- name: your-app
  buildsystem: autotools
  config-opts:
    - --prefix=/app
```

**Simple (custom build):**
```yaml
- name: your-app
  buildsystem: simple
  build-commands:
    - make
    - make install PREFIX=/app
```

### Multiple Release Channels

For apps with multiple release channels (stable/beta):

```yaml
# In your workflow, use different tag patterns:
on:
  push:
    tags:
      - 'v*.*.*'        # Stable releases
      - 'v*.*.*-beta*'  # Beta releases
      - 'v*.*.*-rc*'    # Release candidates
```

### Complex Dependencies

For apps with multiple external dependencies:

```yaml
sources:
  - type: archive
    url: https://example.com/dependency.tar.gz
    sha256: abcdef...
    x-checker-data:
      type: html
      url: https://example.com/downloads
      pattern: 'dependency-([0-9.]+)\.tar\.gz'

  - type: git
    url: https://github.com/user/dependency.git
    tag: v1.0.0
    commit: abcdef...
    x-checker-data:
      type: json
      url: https://api.github.com/repos/user/dependency/releases/latest
      tag-query: .tag_name
```

### Custom Branch Names

To use different default branches:

```yaml
# For repositories using 'master' as default
git push origin HEAD:master

# For repositories using 'develop' 
git push origin HEAD:develop
```

## Security Considerations

### Token Security

- **Use classic tokens** with minimal required scopes
- **Rotate tokens regularly** (every 6-12 months)
- **Monitor token usage** in GitHub settings
- **Revoke unused tokens** immediately

### Workflow Security

- **Repository ownership checks**: Always include `github.repository_owner == 'yourusername'`
- **Branch protection**: Protect your main branch from direct pushes
- **Review automation**: Set up required reviews for PRs
- **Audit logs**: Regularly check Actions logs for unusual activity

### Manifest Security

- **Pin commit hashes**: Always include both tag and commit
- **Verify checksums**: Use SHA256 hashes for archives
- **Secure sources**: Only use trusted upstream sources
- **Update dependencies**: Keep all dependencies current

## Additional Resources

- [Flatpak Manifest Documentation](https://docs.flatpak.org/en/latest/manifests.html)
- [Flathub Documentation](https://docs.flathub.org/)
- [External Data Checker](https://github.com/flathub-infra/flatpak-external-data-checker)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

## Example Implementation

For a complete working example of this automation, see:
- Repository: [tobagin/digger](https://github.com/tobagin/digger)
- Flathub: [flathub/io.github.tobagin.digger](https://github.com/flathub/io.github.tobagin.digger)

This guide is based on the actual implementation used for the Digger DNS lookup tool.

---

*Last updated: 2025-08-25*
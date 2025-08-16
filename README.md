# Digger - DNS Lookup Tool

A modern DNS lookup tool built with Vala, GTK4, and libadwaita. Digger provides an intuitive interface for performing DNS queries, viewing results, and managing query history.

![Digger Screenshot](https://via.placeholder.com/800x600/3584e4/white?text=Digger+DNS+Tool)

## Features

- 🔍 **Comprehensive DNS Queries**: Support for all major DNS record types (A, AAAA, CNAME, MX, NS, PTR, TXT, SOA, SRV, ANY)
- ⚙️ **Advanced Options**: Reverse DNS lookup, trace queries, custom DNS servers, and short output format
- 📝 **Query History**: Persistent history with search and filtering capabilities
- 📋 **Clipboard Integration**: One-click copying of DNS record values
- ⌨️ **Keyboard Shortcuts**: Efficient navigation with keyboard shortcuts
- 🎨 **Modern Interface**: Clean, adaptive UI built with libadwaita
- 🌐 **Network Diagnostics**: Detailed error handling and network troubleshooting

## Installation

### Prerequisites

**Fedora/RHEL:**
```bash
sudo dnf install vala meson gtk4-devel libadwaita-devel json-glib-devel libgee-devel bind-utils
```

**Ubuntu/Debian:**
```bash
sudo apt install valac meson libgtk-4-dev libadwaita-1-dev libjson-glib-dev libgee-0.8-dev dnsutils
```

**Arch Linux:**
```bash
sudo pacman -S vala meson gtk4 libadwaita json-glib gee bind
```

### Flatpak (Recommended)

```bash
# Install from Flathub (when available)
flatpak install flathub io.github.tobagin.digger
flatpak run io.github.tobagin.digger
```

### Building from Source

#### Using Flatpak Builder
```bash
git clone https://github.com/tobagin/digger-vala.git
cd digger-vala

# Install Flatpak build dependencies
sudo dnf install flatpak flatpak-builder  # Fedora/RHEL
# sudo apt install flatpak flatpak-builder  # Ubuntu/Debian
# sudo pacman -S flatpak flatpak-builder    # Arch Linux

# Add Flathub repository and install GNOME SDK
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gnome.Platform//48 org.gnome.Sdk//48

# Build and install the Flatpak (Production)
flatpak-builder --user --install --force-clean builddir io.github.tobagin.digger.yml
flatpak run io.github.tobagin.digger

# Build and install the Flatpak (Development)
flatpak-builder --user --install --force-clean builddir io.github.tobagin.digger.Devel.yml
flatpak run io.github.tobagin.digger.Devel
```

#### Traditional Build
```bash
git clone https://github.com/tobagin/digger-vala.git
cd digger-vala
meson setup builddir
meson compile -C builddir
sudo meson install -C builddir
```

### Development

```bash
# Run without installing
./builddir/digger-vala

# Enable debug logging
G_MESSAGES_DEBUG=all ./builddir/digger-vala
```

## Usage

### Basic DNS Lookup
1. Enter a domain name (e.g., `example.com`)
2. Select the DNS record type
3. Click "Look up DNS records" or press Enter

### Advanced Options
Expand the "Advanced Options" section to access:
- **Reverse DNS Lookup**: Check for IP address reverse resolution
- **Trace Query Path**: See the full resolution path from root servers
- **Short Output**: Get minimal, essential output only
- **Custom DNS Server**: Specify a custom DNS server (e.g., 8.8.8.8)

### Keyboard Shortcuts
- `Ctrl+L`: Focus the domain entry field
- `Ctrl+R`: Repeat the last query
- `Escape`: Clear results and return to empty state
- `Enter`: Submit query when in any input field

### Query History
- Access history via the history button in the header
- Search through previous queries
- Click any history item to repeat the query
- Clear history when needed

## Architecture

Digger follows a clean, modular architecture:

```
digger-vala/
├── src/
│   ├── main.vala              # Application entry point
│   ├── application.vala       # Main application class
│   ├── window.vala           # Main window and UI logic
│   ├── dns-query.vala        # DNS query backend
│   ├── dns-record.vala       # Data models and types
│   ├── query-history.vala    # History management
│   ├── query-result-view.vala # Results display
│   └── advanced-options.vala # Advanced options panel
├── data/                     # Application data files
└── po/                      # Translations
```

## DNS Integration

Digger uses the system `dig` command for DNS resolution, providing:
- Robust error handling for network issues
- Support for all standard DNS record types
- Advanced query options like tracing and custom servers
- Detailed query timing and status information

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Coding Guidelines
- Follow existing code style and patterns
- Add appropriate error handling
- Include descriptive commit messages
- Test changes with various DNS queries

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Vala](https://vala.dev/) and [GTK4](https://gtk.org/)
- UI components from [libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/)
- Inspired by the classic `dig` command-line tool
- Thanks to the GNOME and GTK communities for excellent documentation

---

**Note**: Digger requires the `dig` command to be installed on your system. This is typically provided by the `bind-utils` (Fedora/RHEL), `dnsutils` (Ubuntu/Debian), or `bind` (Arch Linux) packages.

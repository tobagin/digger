# Digger

<p align="center">
  <img src="io.github.tobagin.digger.png" alt="Digger Logo" width="128" height="128"/>
</p>

A modern DNS lookup tool that provides a user-friendly graphical interface for the `dig` command. Digger simplifies DNS queries by presenting results in a structured, easily understandable format.

## Features

- 🔍 **Comprehensive DNS Support**: Query A, AAAA, MX, TXT, NS, CNAME, and SOA records
- 🖥️ **Modern Interface**: Built with GTK4 and LibAdwaita following GNOME Human Interface Guidelines
- ⚡ **Responsive Design**: Background query processing keeps the UI smooth and responsive
- 🛠️ **Custom DNS Servers**: Specify your own DNS server for queries
- 📊 **Structured Results**: Clear display of Answer, Authority, and Additional sections
- 🔧 **Error Handling**: Graceful handling of network issues, invalid domains, and missing dependencies
- 📋 **Copy Support**: Easy copying of DNS record values
- ⌨️ **Keyboard Shortcuts**: Quick access with keyboard shortcuts (Ctrl+L, Ctrl+R, Escape)

## Installation

### From Flathub (Recommended)

*Coming soon - Digger will be available on Flathub once approved*

```bash
flatpak install flathub io.github.tobagin.digger
```

### Local Development Build

#### Prerequisites

- Python 3.9 or later
- GTK4 and LibAdwaita development libraries
- The `dig` command (usually from `dnsutils` or `bind-utils` package)

#### System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install python3-dev python3-venv python3-pip \
                 libgtk-4-dev libadwaita-1-dev \
                 gobject-introspection libgirepository1.0-dev \
                 dnsutils
```

**Fedora:**
```bash
sudo dnf install python3-devel python3-pip \
                 gtk4-devel libadwaita-devel \
                 gobject-introspection-devel \
                 bind-utils
```

**Arch Linux:**
```bash
sudo pacman -S python python-pip \
               gtk4 libadwaita \
               gobject-introspection \
               bind-tools
```

#### Building from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/tobagin/digger.git
   cd digger
   ```

2. **Set up virtual environment:**
   ```bash
   python -m venv venv_linux
   source venv_linux/bin/activate  # On Windows: venv_linux\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -e ".[dev]"
   ```

4. **Run the application:**
   ```bash
   python -m digger.main
   ```

### Flatpak Development Build

Build and install locally for testing:

```bash
# Install Flatpak SDK
flatpak install org.gnome.Platform//48 org.gnome.Sdk//48

# Build development version
flatpak-builder build-dir io.github.tobagin.digger.dev.yml --force-clean --install --user

# Run development version
flatpak run io.github.tobagin.digger.dev
```

## Usage

### Basic DNS Lookup

1. **Launch Digger** from your application menu or command line
2. **Enter a domain name** (e.g., `example.com`)
3. **Select record type** (A, AAAA, MX, TXT, NS, CNAME, SOA)
4. **Optionally specify a DNS server** (e.g., `8.8.8.8`)
5. **Click "Lookup"** or press Enter

### Keyboard Shortcuts

- **Ctrl+L**: Focus the domain entry field
- **Ctrl+R**: Repeat the last query
- **Escape**: Clear results and return to empty state
- **Enter**: Submit query when in any input field

### Understanding Results

Digger displays DNS results in organized sections:

- **Query Information**: Shows the domain queried, record type, DNS server used, query time, and status
- **Answer Section**: Direct answers to your query
- **Authority Section**: Authoritative name servers for the domain
- **Additional Section**: Additional records that may be helpful

Each record shows:
- **Record Name**: The queried domain or subdomain
- **Record Type**: Type of DNS record (A, MX, etc.)
- **TTL**: Time to Live in seconds
- **Value**: The actual DNS record value

### Error Handling

Digger gracefully handles common issues:

- **Missing `dig` command**: Shows installation instructions
- **Network connectivity**: Displays network error messages
- **Invalid domains**: Validates domain format before querying
- **DNS resolution failures**: Shows NXDOMAIN, SERVFAIL status clearly
- **Query timeouts**: Handles and reports timeout conditions

## Architecture

Digger follows a clean, modular architecture:

```
digger/
├── backend/           # Core functionality
│   ├── models.py      # Pydantic data models
│   ├── dig_executor.py # Subprocess management
│   └── dig_parser.py  # Output parsing
├── ui/                # GTK4/LibAdwaita interface
│   ├── main_window.py   # Application window
│   ├── query_widget.py  # Query input form
│   └── results_widget.py # Results display
└── main.py           # Application entry point
```

### Key Components

- **Models**: Pydantic models ensure type safety and data validation
- **Executor**: Manages `dig` subprocess execution with proper threading
- **Parser**: Robust parsing of `dig` output supporting all record types
- **UI Components**: Modern GTK4/LibAdwaita widgets following GNOME HIG

## Development

### Running Tests

```bash
# Activate virtual environment
source venv_linux/bin/activate

# Run all tests
pytest tests/ -v

# Run specific test category
pytest tests/backend/ -v
```

### Code Quality

```bash
# Format code
black digger/ tests/

# Lint code
ruff check digger/ tests/ --fix

# Type checking
mypy digger/backend/
```

### Project Structure Requirements

- **File size limit**: No file should exceed 500 lines
- **Type hints**: All functions must include type annotations
- **Documentation**: Google-style docstrings for all functions
- **Testing**: Comprehensive unit tests for all backend components

## Requirements

### Runtime Requirements

- **Python**: 3.9 or later
- **GTK**: 4.0 or later
- **LibAdwaita**: 1.0 or later
- **dig command**: For DNS queries

### Python Dependencies

- `PyGObject>=3.46.0` - GTK/LibAdwaita bindings
- `pydantic>=2.0` - Data validation and parsing
- `python-dotenv>=1.0.0` - Environment configuration

### Development Dependencies

- `pytest>=7.0` - Testing framework
- `black>=23.0` - Code formatting
- `ruff>=0.1.0` - Linting
- `mypy>=1.0` - Type checking

## Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature-name`
3. **Make your changes** following the coding standards
4. **Add tests** for new functionality
5. **Run the test suite**: `pytest tests/`
6. **Commit changes**: `git commit -m "Add feature"`
7. **Push to branch**: `git push origin feature-name`
8. **Create Pull Request**

### Coding Standards

- Follow **PEP 8** style guidelines
- Use **black** for code formatting
- Include **type hints** for all functions
- Write **comprehensive tests** for new features
- Keep files **under 500 lines**
- Use **Google-style docstrings**

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **GTK4** and **LibAdwaita** teams for the excellent toolkit
- **GNOME** project for the Human Interface Guidelines
- **dig** command maintainers for the robust DNS lookup utility
- **Pydantic** team for the data validation framework

## Support

- **Issues**: [GitHub Issues](https://github.com/tobagin/digger/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tobagin/digger/discussions)
- **Documentation**: This README and inline code documentation

---

<p align="center">Made with ❤️ for the GNOME community</p>
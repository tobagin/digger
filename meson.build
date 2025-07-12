project('digger',
  version: '1.0.0',
  meson_version: '>= 0.59.0',
  default_options: [
    'warning_level=2',
    'werror=false',
  ]
)

python = import('python')
gnome = import('gnome')

python_installation = python.find_installation('python3')

# Configuration data
conf = configuration_data()
conf.set('VERSION', meson.project_version())
conf.set('PACKAGE_NAME', meson.project_name())
conf.set('PACKAGE_URL', 'https://github.com/tobagin/digger')

# Application ID
application_id = 'io.github.tobagin.digger'

# Directories
bindir = get_option('bindir')
datadir = get_option('datadir')
pkgdatadir = datadir / application_id

# Dependencies
dependency('glib-2.0', version: '>= 2.66')
dependency('gtk4', version: '>= 4.0')
dependency('libadwaita-1', version: '>= 1.0')

# Python dependencies are managed via pip/virtual environment
# We assume they are available at build time

# Subdirectories
subdir('digger')
subdir('data')
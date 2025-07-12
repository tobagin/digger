# Find blueprint-compiler
blueprint_compiler = find_program('blueprint-compiler')

# Compile Blueprint files to UI files
ui_files = [
  custom_target('main_window.ui',
    input: 'ui/blueprints/main_window.blp',
    output: 'main_window.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
  ),
  custom_target('query_widget.ui',
    input: 'ui/blueprints/query_widget.blp',
    output: 'query_widget.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
  ),
  custom_target('results_widget.ui',
    input: 'ui/blueprints/results_widget.blp',
    output: 'results_widget.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
  ),
  custom_target('history_widget.ui',
    input: 'ui/blueprints/history_widget.blp',
    output: 'history_widget.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
  ),
  custom_target('history_popover.ui',
    input: 'ui/blueprints/history_popover.blp',
    output: 'history_popover.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
  ),
  custom_target('settings_dialog.ui',
    input: 'ui/blueprints/settings_dialog.blp',
    output: 'settings_dialog.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
  ),
]

# Create GResource file (for Python applications, we generate a .gresource file)
resource_files = gnome.compile_resources(
  'digger-resources',
  'ui/digger.gresource.xml',
  source_dir: 'ui',
  dependencies: ui_files,
  install: true,
  install_dir: pkgdatadir,
  gresource_bundle: true,
)

# Install Python modules
python_sources = [
  '__init__.py',
  'main.py',
]

backend_sources = [
  'backend/__init__.py',
  'backend/dig_executor.py',
  'backend/dig_parser.py',
  'backend/history.py',
  'backend/models.py',
]

ui_sources = [
  'ui/__init__.py',
  'ui/main_window_blueprint.py',
  'ui/query_widget_blueprint.py',
  'ui/results_widget_blueprint.py',
  'ui/history_widget_blueprint.py',
  'ui/settings_dialog.py',
]

# Install Python files
python_installation.install_sources(
  python_sources,
  subdir: 'digger'
)

python_installation.install_sources(
  backend_sources,
  subdir: 'digger/backend'
)

python_installation.install_sources(
  ui_sources,
  subdir: 'digger/ui'
)

# Configure and install the main script
conf_main = configuration_data()
conf_main.set('PYTHON', python_installation.full_path())
conf_main.set('PACKAGE_NAME', meson.project_name())
conf_main.set('VERSION', meson.project_version())
conf_main.set('PKGDATADIR', pkgdatadir)

configure_file(
  input: 'main.py.in',
  output: 'digger',
  configuration: conf_main,
  install: true,
  install_dir: bindir,
  install_mode: 'rwxr-xr-x'
)
# Data files meson.build

# Configure template files
desktop_input = configure_file(
  input: 'io.github.tobagin.digger.desktop.in',
  output: app_id + '.desktop.in',
  configuration: {
    'APP_ID': app_id,
    'APP_NAME': app_name
  }
)

metainfo_input = configure_file(
  input: 'io.github.tobagin.digger.metainfo.xml.in',
  output: app_id + '.metainfo.xml.in',
  configuration: {
    'APP_ID': app_id
  }
)

# Desktop file
desktop_file = i18n.merge_file(
  input: desktop_input,
  output: app_id + '.desktop',
  type: 'desktop',
  po_dir: join_paths(meson.current_source_dir(), '..', 'po'),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

# Metainfo file
metainfo_file = i18n.merge_file(
  input: metainfo_input,
  output: app_id + '.metainfo.xml',
  type: 'xml',
  po_dir: join_paths(meson.current_source_dir(), '..', 'po'),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Configure and install GSchema
gschema_file = configure_file(
  input: 'io.github.tobagin.digger.gschema.xml',
  output: app_id + '.gschema.xml',
  configuration: {
    'APP_ID': app_id,
    'APP_ID_PATH': app_id.replace('.', '/')
  }
)

install_data(gschema_file,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

# Compile GSettings schemas for build time
gnome.compile_schemas(build_by_default: true)

# Import fs module
fs = import('fs')

# Blueprint files - organized by category
blueprint_files = [
  # Main window
  'ui/window.blp',
  # Dialogs
  'ui/dialogs/preferences-dialog.blp',
  'ui/dialogs/shortcuts-dialog.blp',
  'ui/dialogs/batch-lookup-dialog.blp',
  'ui/dialogs/comparison-dialog.blp',
  'ui/dialogs/history-dialog.blp',
  'ui/dialogs/autocomplete-dialog.blp',
  # Widgets
  'ui/widgets/enhanced-query-form.blp',
  'ui/widgets/enhanced-result-view.blp',
  'ui/widgets/advanced-options.blp',
  'ui/widgets/autocomplete-dropdown.blp',
  'ui/widgets/enhanced-history-search.blp',
  'ui/widgets/history-popover.blp',
]

# Compile blueprint files to UI files
ui_files = []
foreach blueprint_file : blueprint_files
  # Get just the filename without .blp
  filename = fs.stem(blueprint_file) + '.ui'

  ui_files += custom_target(
    filename,
    input: blueprint_file,
    output: filename,
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'digger', 'ui', fs.parent(blueprint_file).replace('ui/', ''))
  )
endforeach

# Configure GResources file
gresource_xml = configure_file(
  input: 'digger.gresource.xml',
  output: 'digger.gresource.xml',
  configuration: {
    'APP_ID_PATH': '/' + app_id.replace('.', '/')
  }
)

# GResources
digger_resources = gnome.compile_resources(
  'digger-resources',
  gresource_xml,
  dependencies: ui_files,
  source_dir: [meson.current_build_dir(), meson.current_source_dir()],
  c_name: 'digger'
)

# Install main scalable SVG icon
install_data(
  join_paths('icons', 'hicolor', 'scalable', 'apps', 'io.github.tobagin.digger.svg'),
  rename: app_id + '.svg',
  install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)

# Install scalable symbolic icons
scalable_icons = [
  'history-symbolic',
  'copy-symbolic',
  'error-symbolic',
  'success-symbolic',
  'fastest-server-symbolic',
  'slowest-server-symbolic',
  'average-query-time-symbolic',
  'query-time-symbolic'
]
foreach icon : scalable_icons
  # Use consistent naming for all symbolic icons
  output_name = app_id + '-' + icon + '.svg'

  configure_file(
    input: join_paths('icons', 'hicolor', 'scalable', 'apps', 'io.github.tobagin.digger-' + icon + '.svg'),
    output: output_name,
    copy: true,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
  )
endforeach

# Preset data files
install_data(
  'presets/dns-servers.json',
  'presets/record-types.json',
  install_dir: join_paths(get_option('datadir'), 'digger', 'presets')
)

# CSS themes
install_subdir('themes',
  install_dir: join_paths(get_option('datadir'), 'digger'),
  strip_directory: false
)

# Screenshots
install_subdir('screenshots',
  install_dir: join_paths(get_option('datadir'), 'digger'),
  strip_directory: false
)

# Data files meson.build

# Configure template files
desktop_input = configure_file(
  input: 'io.github.tobagin.digger.desktop.in',
  output: app_id + '.desktop.in',
  configuration: {
    'APP_ID': app_id
  }
)

appdata_input = configure_file(
  input: 'io.github.tobagin.digger.appdata.xml.in',
  output: app_id + '.appdata.xml.in',
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

# Appdata file
appdata_file = i18n.merge_file(
  input: appdata_input,
  output: app_id + '.appdata.xml',
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

# Blueprint files
blueprint_files = [
  'ui/window.blp',
  'ui/enhanced-query-form.blp',
  'ui/enhanced-result-view.blp',
  'ui/advanced-options.blp',
  'ui/autocomplete-dropdown.blp',
  'ui/enhanced-history-search.blp',
  'ui/history-popover.blp',
]

# Compile blueprint files to UI files
ui_files = []
foreach blueprint_file : blueprint_files
  ui_file = fs.stem(blueprint_file) + '.ui'
  ui_files += custom_target(
    ui_file,
    input: blueprint_file,
    output: ui_file,
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
    build_by_default: true
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

# Icons - copy with dynamic name
configure_file(
  input: 'icons/io.github.tobagin.digger.svg',
  output: app_id + '.svg',
  copy: true,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)

# Preset data files
install_data(
  'presets/dns-servers.json',
  'presets/record-types.json',
  install_dir: join_paths(get_option('datadir'), 'digger', 'presets')
)

# CSS themes
install_subdir('../assets/themes',
  install_dir: join_paths(get_option('datadir'), 'digger'),
  strip_directory: false
)

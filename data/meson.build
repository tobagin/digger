# Data files meson.build

# Desktop file
desktop_file = i18n.merge_file(
  input: 'io.github.tobagin.digger.desktop.in',
  output: 'io.github.tobagin.digger.desktop',
  type: 'desktop',
  po_dir: join_paths(meson.current_source_dir(), '..', 'po'),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

# Appdata file
appdata_file = i18n.merge_file(
  input: 'io.github.tobagin.digger.appdata.xml.in',
  output: 'io.github.tobagin.digger.appdata.xml',
  type: 'xml',
  po_dir: join_paths(meson.current_source_dir(), '..', 'po'),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# GSchema
install_data('io.github.tobagin.digger.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

# Compile GSettings schemas
gnome = import('gnome')
gnome.compile_schemas(build_by_default: true)

# Icons
install_data('icons/io.github.tobagin.digger.svg',
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

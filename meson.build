project('digger-vala', 'vala', 'c',
  version: '2.3.0',
  default_options: ['warning_level=1'],
  meson_version: '>= 0.58.0'
)

# Build options
development = get_option('development')

# Check for Vala compiler
vala = meson.get_compiler('vala')
i18n = import('i18n')
gnome = import('gnome')

# Check for blueprint compiler
blueprint_compiler = find_program('blueprint-compiler', required: false)
if not blueprint_compiler.found()
  error('blueprint-compiler not found. Install it with: pip3 install --user blueprint-compiler')
endif

# Dependencies
gtk4_dep = dependency('gtk4', version: '>= 4.6.0')
libadwaita_dep = dependency('libadwaita-1', version: '>= 1.0')
json_glib_dep = dependency('json-glib-1.0')
gio_dep = dependency('gio-2.0')
gee_dep = dependency('gee-0.8')
soup_dep = dependency('libsoup-3.0')

# Configuration data
app_id = development ? 'io.github.tobagin.digger.Devel' : 'io.github.tobagin.digger'
conf_data = configuration_data()
conf_data.set('VERSION', meson.project_version())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
conf_data.set('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))
conf_data.set('APP_ID', app_id)
conf_data.set('DEVELOPMENT', development.to_string())
conf_data.set('RESOURCE_PATH', '/' + app_id.replace('.', '/'))

# Generate config file
config_vala = configure_file(
  input: 'src/Config.vala.in',
  output: 'Config.vala',
  configuration: conf_data
)

# Data subdirectory (must be processed before executable to generate resources)
subdir('data')

# Vala args based on development mode
vala_args = []
if development
  vala_args += ['--define=DEVELOPMENT']
endif

# Application executable
executable('digger-vala',
  'src/Main.vala',
  'src/Application.vala',
  'src/dialogs/Window.vala',
  'src/dialogs/AboutDialog.vala',
  'src/dialogs/PreferencesDialog.vala',
  'src/dialogs/ShortcutsDialog.vala',
  'src/dialogs/BatchLookupDialog.vala',
  'src/dialogs/ComparisonDialog.vala',
  'src/models/DnsRecord.vala',
  'src/services/DnsQuery.vala',
  'src/services/QueryHistory.vala',
  'src/services/SecureDns.vala',
  'src/services/DnssecValidator.vala',
  'src/managers/ExportManager.vala',
  'src/managers/FavoritesManager.vala',
  'src/managers/BatchLookupManager.vala',
  'src/managers/ComparisonManager.vala',
  'src/widgets/QueryResultView.vala',
  'src/widgets/AdvancedOptions.vala',
  'src/widgets/EnhancedQueryForm.vala',
  'src/widgets/EnhancedResultView.vala',
  'src/widgets/AutocompleteDropdown.vala',
  'src/widgets/EnhancedHistorySearch.vala',
  'src/utils/ThemeManager.vala',
  'src/utils/DnsPresets.vala',
  'src/utils/DomainSuggestions.vala',
  'src/utils/ValidationUtils.vala',
  'src/utils/Constants.vala',
  'src/utils/CollectionUtils.vala',
  config_vala,
  digger_resources,
  dependencies: [
    gtk4_dep,
    libadwaita_dep,
    json_glib_dep,
    gio_dep,
    gee_dep,
    soup_dep
  ],
  vala_args: vala_args,
  install: true,
  install_dir: get_option('bindir')
)

# Po files
subdir('po')

# Post-install hooks
gnome.post_install(
  glib_compile_schemas: true
)

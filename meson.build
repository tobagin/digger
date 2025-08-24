project('digger-vala', 'vala', 'c',
  version: '2.0.9',
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
  input: 'src/config.vala.in',
  output: 'config.vala',
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
  'src/main.vala',
  'src/application.vala',
  'src/window.vala',
  'src/preferences-dialog.vala',
  'src/shortcuts-dialog.vala',
  'src/dns-query.vala',
  'src/dns-record.vala',
  'src/query-history.vala',
  'src/query-result-view.vala',
  'src/advanced-options.vala',
  'src/features/dns-presets.vala',
  'src/features/domain-suggestions.vala',
  'src/ui/enhanced-query-form.vala',
  'src/ui/enhanced-result-view.vala',
  'src/ui/autocomplete-dropdown.vala',
  'src/ui/enhanced-history-search.vala',
  'src/ui/theme-manager.vala',
  config_vala,
  digger_resources,
  dependencies: [
    gtk4_dep,
    libadwaita_dep,
    json_glib_dep,
    gio_dep,
    gee_dep
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

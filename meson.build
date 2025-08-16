project('digger-vala', 'vala', 'c',
  version: '1.0.0',
  default_options: ['warning_level=3'],
  meson_version: '>= 0.58.0'
)

# Check for Vala compiler
vala = meson.get_compiler('vala')
i18n = import('i18n')

# Dependencies
gtk4_dep = dependency('gtk4', version: '>= 4.6.0')
libadwaita_dep = dependency('libadwaita-1', version: '>= 1.0')
json_glib_dep = dependency('json-glib-1.0')
gio_dep = dependency('gio-2.0')
gee_dep = dependency('gee-0.8')

# Configuration data
conf_data = configuration_data()
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
conf_data.set_quoted('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))
conf_data.set_quoted('APP_ID', 'io.github.tobagin.digger')

# Generate config file
config_header = configure_file(
  input: 'src/config.vala.in',
  output: 'config.vala',
  configuration: conf_data
)

# Application executable
executable('digger-vala',
  sources: [
    'src/main.vala',
    'src/application.vala',
    'src/window.vala',
    'src/dns-query.vala',
    'src/dns-record.vala',
    'src/query-history.vala',
    'src/query-result-view.vala',
    'src/advanced-options.vala',
    config_header
  ],
  dependencies: [
    gtk4_dep,
    libadwaita_dep,
    json_glib_dep,
    gio_dep,
    gee_dep
  ],
  install: true,
  install_dir: get_option('bindir')
)

# Data files
subdir('data')
subdir('po')

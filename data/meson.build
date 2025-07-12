# Desktop file
desktop_file = configure_file(
  input: 'io.github.tobagin.digger.desktop.in',
  output: 'io.github.tobagin.digger.desktop',
  configuration: conf,
  install: true,
  install_dir: datadir / 'applications'
)

# Validate desktop file
if find_program('desktop-file-validate', required: false).found()
  test('validate-desktop',
    find_program('desktop-file-validate'),
    args: [desktop_file],
  )
endif

# AppData file
appdata_file = configure_file(
  input: 'io.github.tobagin.digger.metainfo.xml.in',
  output: 'io.github.tobagin.digger.metainfo.xml',
  configuration: conf,
  install: true,
  install_dir: datadir / 'metainfo'
)

# Validate AppData file
if find_program('appstreamcli', required: false).found()
  test('validate-appdata',
    find_program('appstreamcli'),
    args: ['validate', '--no-net', appdata_file],
  )
endif

# Icons
icon_sizes = ['16x16', '22x22', '24x24', '32x32', '48x48', '64x64', '128x128', '256x256', '512x512']

foreach size : icon_sizes
  install_data(
    'icons' / 'hicolor' / size / 'apps' / 'io.github.tobagin.digger.png',
    install_dir: datadir / 'icons' / 'hicolor' / size / 'apps',
    rename: 'io.github.tobagin.digger.png'
  )
endforeach

# Symbolic icons
symbolic_icons = [
  'success',
  'error',
  'copy'
]

foreach icon : symbolic_icons
  install_data(
    'icons' / 'hicolor' / 'scalable' / 'apps' / f'io.github.tobagin.digger-@icon@-symbolic.svg',
    install_dir: datadir / 'icons' / 'hicolor' / 'scalable' / 'apps'
  )
endforeach
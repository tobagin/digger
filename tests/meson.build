project_root = meson.project_source_root()

threat_test_exe = executable('test-threat-intel',
  'test-threat-intel.vala',
  project_root / 'src/models/DnsRecord.vala',
  project_root / 'src/services/ThreatIntelService.vala',
  project_root / 'src/utils/ValidationUtils.vala',
  project_root / 'src/utils/Constants.vala',
  project_root / 'src/services/DnsQuery.vala',
  config_vala,
  dependencies: [
    gio_dep,
    gee_dep,
    json_glib_dep,
    soup_dep,
  ],
)

test('threat-intel', threat_test_exe)

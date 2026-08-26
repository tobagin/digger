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

validator_test_exe = executable('test-dns-record-validator',
  'test-dns-record-validator.vala',
  project_root / 'src/models/DnsRecord.vala',
  project_root / 'src/utils/DnsRecordValidator.vala',
  project_root / 'src/utils/ValidationUtils.vala',
  project_root / 'src/utils/Constants.vala',
  config_vala,
  dependencies: [
    gio_dep,
    gee_dep,
    json_glib_dep,
  ],
)

test('dns-record-validator', validator_test_exe)

template_test_exe = executable('test-template-manager',
  'test-template-manager.vala',
  project_root / 'src/managers/TemplateManager.vala',
  project_root / 'src/models/DnsRecord.vala',
  project_root / 'src/utils/ValidationUtils.vala',
  project_root / 'src/utils/Constants.vala',
  project_root / 'src/utils/DnsRecordValidator.vala',
  config_vala,
  dependencies: [ gio_dep, gee_dep, json_glib_dep ],
)
test('template-manager', template_test_exe)
ipv6_test_exe = executable('test-ipv6',
  'test-ipv6.vala',
  project_root / 'src/models/DnsRecord.vala',
  project_root / 'src/services/Ipv6Service.vala',
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

test('ipv6', ipv6_test_exe)

class corp104_snmp_exporter::service inherits corp104_snmp_exporter {

  $real_provider = $corp104_snmp_exporter::init_style ? {
    'sles'  => 'redhat',  # mimics puppet's default behaviour
    'sysv'  => 'redhat',  # all currently used cases for 'sysv' are redhat-compatible
    default => $corp104_snmp_exporter::init_style,
  }

  service { 'snmp-exporter':
    ensure   => $corp104_snmp_exporter::service_ensure,
    name     => $service_name,
    enable   => $corp104_snmp_exporter::service_enable,
    provider => $real_provider,
  }

}

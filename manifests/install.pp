class corp104_snmp_exporter::install (
  String    $package_name         = $corp104_snmp_exporter::package_name,
  String    $version              = $corp104_snmp_exporter::version,
  String    $package_ensure       = 'installed',
  String    $install_method       = $corp104_snmp_exporter::install_method,
  String    $download_url         = $corp104_snmp_exporter::download_url,
  String    $download_extension   = 'tar.gz',
  String    $bin_dir              = $corp104_snmp_exporter::bin_dir,
  String    $service_name         = $corp104_snmp_exporter::service_name,
  String    $http_proxy           = $corp104_snmp_exporter::http_proxy,
  String    $init_style           = $corp104_snmp_exporter::init_style,
  Optional[String] $env_file_path = $corp104_snmp_exporter::env_file_path,
)inherits corp104_snmp_exporter {

  # proxy_server 
  $proxy_server = empty($http_proxy) ? {
    true    => undef,
    default => $http_proxy,
  }
   
  $os_arch = $facts['architecture'] ? {
    'i386'   => '386',
    'x86_64' => 'amd64',
    'amd64'  => 'amd64',
    default  => 'amd64',
  }

  $install_dir = "/opt/${package_name}-${version}.linux-${os_arch}/${package_name}"

  # installation for snmp_exporter
  case $install_method {
    'url': {
      archive { "/tmp/${package_name}-${version}.tar.gz":
        ensure          => present,
        extract         => true,
        extract_path    => '/opt',
        source          => $download_url,
        checksum_verify => false,
        creates         => $install_dir,
        cleanup         => true,
        proxy_server    => $proxy_server,
      }

      file { "/opt/${package_name}-${version}.linux-${os_arch}/${package_name}":
          owner => 'root',
          group => 0, # 0 instead of root because OS X uses "wheel".
          mode  => '0555',
      }
      -> file { "${bin_dir}/${service_name}":
          ensure => link,
          notify => Service['snmp-exporter'],
          target => "/opt/${package_name}-${version}.linux-${os_arch}/${package_name}",
      }
    }
    'package': {
      package { $package_name:
        ensure => $package_ensure,
      }
      if $corp104_snmp_exporter::manage_user {
        User[$corp104_snmp_exporter::user] -> Package[$package_name]
      }
    }
    'none': {}
    default: {
      fail("The provided install method ${install_method} is invalid")
    }
  }

  # manage user and group
  if $corp104_snmp_exporter::manage_user {
    ensure_resource ('user', [ $corp104_snmp_exporter::user ], {
      ensure => 'present',
      system => true,
      groups => $corp104_snmp_exporter::extra_groups,
    })

    if $corp104_snmp_exporter::manage_group {
      Group[$corp104_snmp_exporter::group] -> User[$corp104_snmp_exporter::user]
    }
  }
  if $corp104_snmp_exporter::manage_group {
    ensure_resource ('group', [ $corp104_snmp_exporter::group ], {
      ensure => 'present',
      system => true,
    })
  }

  # manage init type
  if $corp104_snmp_exporter::init_style {
    case $corp104_snmp_exporter::init_style {
      'upstart' : {
        file { "/etc/init/${package_name}.conf":
          mode    => '0444',
          owner   => 'root',
          group   => 'root',
          content => template("${module_name}/daemon.upstart.erb"),
          notify  => Service['snmp-exporter'],
        }
        file { "/etc/init.d/${package_name}":
          ensure => link,
          target => '/lib/init/upstart-job',
          owner  => 'root',
          group  => 'root',
          mode   => '0755',
        }
      }
      'systemd' : {
        include 'systemd'
        systemd::unit_file {"${service_name}.service":
          content => template("${module_name}/daemon.systemd.erb"),
          notify  => Service['snmp-exporter'],
        }
      }
      'sysv' : {
        file { "/etc/init.d/${service_name}":
          mode    => '0555',
          owner   => 'root',
          group   => 'root',
          content => template("${module_name}/daemon.sysv.erb"),
          notify  => Service['snmp-exporter'],
        }
      }
      'redhat' : {
        if $facts['os']['family'] == 'RedHat' {
          if $facts['os']['release']['major'] == '5' {
            file { "/etc/init.d/${service_name}":
              mode    => '0555',
              owner   => 'root',
              group   => 'root',
              content => template("${module_name}/daemon.sysv.bash3.erb"),
              notify  => Service['snmp-exporter'],
            }
          }
          else {
            file { "/etc/init.d/${service_name}":
              mode    => '0555',
              owner   => 'root',
              group   => 'root',
              content => template("${module_name}/daemon.sysv.erb"),
              notify  => Service['snmp-exporter'],
            }
          }
        }
      }
      'debian' : {
        file { "/etc/init.d/${service_name}":
          mode    => '0555',
          owner   => 'root',
          group   => 'root',
          content => template("${module_name}/daemon.debian.erb"),
          notify  => Service['snmp-exporter'],
        }
      }
      default : {
        fail("I don't know how to create an init script for style ${init_style}")
      }
    }
  }

  if $corp104_snmp_exporter::env_file_path != undef {
    file { "${env_file_path}/${service_name}":
      mode    => '0644',
      owner   => 'root',
      group   => '0', # Darwin uses wheel
      content => template("${module_name}/daemon.env.erb"),
      notify  => Service['snmp-exporter'],
    }
  }

}

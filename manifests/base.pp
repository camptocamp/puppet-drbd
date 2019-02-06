# == Class: drbd::base
#
# Basic class which installs the drbd modules and tools, and enables the service
# at boot time.
#
# Usage:
#
#   include drbd::base
#
# Require:
#
#   module kmod (git@github.com:camptocamp/puppet-kmod.git)
#
class drbd::base(
  $centos_mirror = 'http://mirror.switch.ch/ftp/mirror/centos/',
  $elrepo_mirror = 'http://elrepo.org/linux/elrepo/'
) {

  case $::operatingsystem {

    'RedHat': {

      case $::operatingsystemmajrelease {
        '6': {

          exec {'install elrepo gpg key':
            command => '/bin/rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org',
            creates => '/etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org',
          } ->
          yumrepo { 'elrepo-drbd':
            descr       => 'DRBD packages ElRepo for RHEL 6',
            baseurl     => "${elrepo_mirror}el6/\$basearch/",
            enabled     => 1,
            gpgcheck    => 1,
            includepkgs => 'drbd*,kmod-drbd*',
          }

          if $::virtual == 'xenu' {
            fail 'DRDB on a XEN instance not supported with RHEL6 yet, sorry.'
          }

          package { 'drbd':
            ensure  => present,
            name    => 'drbd84-utils',
            require => Yumrepo['elrepo-drbd'],
          }

          package { 'drbd-module':
            ensure  => present,
            name    => 'kmod-drbd84',
            require => Yumrepo['elrepo-drbd'],
            before  => Kmod::Load['drbd'],
          }

        }
        default: {

          yumrepo { 'centos-extra-drbd':
            descr       => "DRBD packages from Centos-extras for RHEL ${::operatingsystemmajrelease}",
            baseurl     => "${centos_mirror}${::operatingsystemmajrelease}/extras/\$basearch/",
            enabled     => 1,
            gpgkey      => "${centos_mirror}/RPM-GPG-KEY-CentOS-${::operatingsystemmajrelease}",
            gpgcheck    => 1,
            includepkgs => 'drbd83,kmod-drbd83,kmod-drbd83-xen',
          }

          # ensure file is managed in case we want to purge /etc/yum.repos.d/
          # http://projects.puppetlabs.com/issues/3152
          file { '/etc/yum.repos.d/centos-extra-drbd.repo':
            ensure  => file,
            mode    => '0644',
            owner   => 'root',
            require => Yumrepo['centos-extra-drbd'],
          }

          if $::virtual == 'xenu' {
            $kmodpkg = 'kmod-drbd83-xen'
          } else {
            $kmodpkg = 'kmod-drbd83'
          }

          package { 'drbd':
            ensure  => present,
            name    => 'drbd83',
            require => Yumrepo['centos-extra-drbd'],
          }

          package { 'drbd-module':
            ensure  => present,
            name    => $kmodpkg,
            require => Yumrepo['centos-extra-drbd'],
            before  => Kmod::Load['drbd'],
          }

        }
      }


    }

    'Debian': {
      if $::operatingsystemmajrelease == '6' {
        package { 'drbd':
          ensure => present,
          name   => 'drbd8-utils',
        }
      }
    }

    'Ubuntu': {
      package { 'drbd':
        ensure => present,
        name   => 'drbd8-utils',
      }

      package { 'drbd-module':
        ensure => present,
        name   => 'drbd8-source',
        before => Kmod::Load['drbd'],
      }
    }

    default: {
      fail "Unsupported OS ${::operatingsystem}"
    }
  }

  kmod::load {'drbd': }

  augeas { 'remove legacy modprobe.conf install entry':
    incl    => '/etc/modprobe.d/modprobe.conf',
    lens    => 'Modprobe.lns',
    changes => "rm install[. = 'drbd']",
    onlyif  => "match install[. = 'drbd'] size > 0",
    before  => Kmod::Load['drbd'],
  }

  service { 'drbd':
    ensure    => running,
    hasstatus => true,
    restart   => '/etc/init.d/drbd reload',
    enable    => true,
    require   => [Package['drbd'], Kmod::Load['drbd']],
  }

  # this file just includes other files
  file { '/etc/drbd.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    content => '# file managed by puppet
include "/etc/drbd.conf.d/*.conf";
',
    require => Package['drbd'],
    before  => Service['drbd'],
    notify  => Service['drbd'],
  }

  # only allow files managed by puppet in this directory.
  file { '/etc/drbd.conf.d/':
    ensure  => directory,
    # lint:ignore:fileserver
    source  => 'puppet:///modules/drbd/drbd.conf.d/',
    # lint:endignore
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    purge   => true,
    recurse => true,
    force   => true,
    require => Package['drbd'],
    notify  => Service['drbd'],
  }

}

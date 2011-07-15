/*

== Class: drbd::base

Basic class which installs the drbd modules and tools, and enables the service
at boot time.

Usage:

  include drbd::base

*/
class drbd::base {

  case $operatingsystem {

    RedHat: {

      case $lsbmajdistrelease {
        "6": {
          # Note: as CentOS 6 has not yet been released, we can't fetch drbd
          # packages for RHEL 6 from there. This recipe fetches them from
          # ATrpms. Maybe we can remove this differenciation once CentOS 6 is
          # released.

          yumrepo { "atrpms-drbd":
            descr => "DRBD packages from ATrpms for RHEL ${lsbmajdistrelease}",
	    baseurl => "http://dl.atrpms.net/el6-${architecture}/atrpms/stable",
            enabled => 1,
            gpgkey => "http://packages.atrpms.net/RPM-GPG-KEY.atrpms",
            gpgcheck => 1,
            includepkgs => "drbd,drbd-kmdl-${kernelrelease}",
          }

          # ensure file is managed in case we want to purge /etc/yum.repos.d/
          # http://projects.puppetlabs.com/issues/3152
          file { "/etc/yum.repos.d/atrpms-drbd.repo":
            ensure  => present,
            mode    => 0644,
            owner   => "root",
            require => Yumrepo["atrpms-drbd"],
          }

          if $virtual == "xenu" {
            fail "DRDB on a XEN instance not supported with RHEL6 yet, sorry."
          }

          package { "drbd":
            ensure  => present,
            require => [ Yumrepo["atrpms-drbd"], file["/etc/yum.repos.d/atrpms-drbd.repo"] ],
          }
    
          package { "drbd-kmdl-${kernelrelease}":
            ensure  => present,
            alias   => "drbd-module",
            require => [ Yumrepo["atrpms-drbd"], file["/etc/yum.repos.d/atrpms-drbd.repo"] ],
          }

          # Should probably be created by the drbd package, but is not.
          file { "/var/lib/drbd":
            ensure => directory,
          }

        }
        default: {

          if ( ! $centos_mirror ) {
            $centos_mirror = "http://mirror.switch.ch/ftp/mirror/centos/"
          }

          yumrepo { "centos-extra-drbd":
            descr => "DRBD packages from Centos-extras for RHEL ${lsbmajdistrelease}",
            baseurl => "${centos_mirror}${operatingsystemrelease}/extras/${architecture}/",
            enabled => 1,
            gpgkey => "${centos_mirror}/RPM-GPG-KEY-CentOS-${lsbmajdistrelease}",
            gpgcheck => 1,
            includepkgs => "drbd83,kmod-drbd83,kmod-drbd83-xen",
          }

          # ensure file is managed in case we want to purge /etc/yum.repos.d/
          # http://projects.puppetlabs.com/issues/3152
          file { "/etc/yum.repos.d/centos-extra-drbd.repo":
            ensure  => present,
            mode    => 0644,
            owner   => "root",
            require => Yumrepo["centos-extra-drbd"],
          }

          if $virtual == "xenu" {
            $kmodpkg = "kmod-drbd83-xen"
          } else {
            $kmodpkg = "kmod-drbd83"
          }

          package { "drbd83":
            ensure  => present,
            alias   => "drbd",
            require => Yumrepo["centos-extra-drbd"],
          }
    
          package { $kmodpkg:
            ensure  => present,
            alias   => "drbd-module",
            require => Yumrepo["centos-extra-drbd"],
          }

        }
      }


    }

    Debian: {
      case $lsbmajdistrelease {
        "6": {

          package { "drbd8-utils":
            ensure  => present,
            alias   => "drbd",
          }

        }
      }
    }

    Ubuntu: {
      package { "drbd8-utils": 
        ensure => present,
        alias => "drbd",
      }

      package { "drbd8-source":
        ensure => present,
        alias => "drbd-module",
      }
    }
  }

  # Build kernel module, if needed
  case $operatingsystem {

    Debian: {

      # this module is included in linux-image-* (kernel) package
      exec { "load drbd module":
        command => "modprobe drbd",
        creates => "/proc/drbd",
      }

      service { "drbd":
        ensure    => running,
        hasstatus => true,
        restart   => "/etc/init.d/drbd reload",
        enable    => true,
        require   => [Package["drbd"], Exec["load drbd module"]],
      }
    }

    default: {

      exec { "load drbd module":
        command => "modprobe drbd",
        creates => "/proc/drbd",
        require => Package["drbd-module"],
      }

      service { "drbd":
        ensure    => running,
        hasstatus => true,
        restart   => "/etc/init.d/drbd reload",
        enable    => true,
        require   => [Package["drbd", "drbd-module"], Exec["load drbd module"]],
      }
    }

  }

  # this file just includes other files
  file { "/etc/drbd.conf":
    ensure  => present,
    mode    => "0644",
    owner   => "root",
    content => '# file managed by puppet
include "/etc/drbd.conf.d/*.conf";
',
    require => Package["drbd"],
    before  => Service["drbd"],
    notify  => Service["drbd"],
  }

  # only allow files managed by puppet in this directory.
  file { "/etc/drbd.conf.d/":
    ensure  => directory,
    source  => "puppet:///drbd/drbd.conf.d/",
    mode    => "0644",
    purge   => true,
    recurse => true,
    force   => true,
    require => Package["drbd"],
    notify  => Service["drbd"],
  }

}

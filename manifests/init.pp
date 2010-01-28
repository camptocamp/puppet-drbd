/*

== Class: drbd::base

Basic class which installs the drbd modules and tools, and enables the service
at boot time.

*/
class drbd::base {

  case $operatingsystem {

    RedHat: {

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

    Debian: {
      #TODO
    }
  }

  service { "drbd":
    ensure    => running,
    hasstatus => true,
    enable    => true,
    require   => Package["drbd", "drbd-module"],
  }

}

define drbd::config ($host1, $host2, $host1_ip, $host2_ip, $port='7789', $secret, $disk, $device='/dev/drbd0', $protocol='C') {

  file { "/etc/drbd.conf":
    content => template("drbd/drbd.conf.erb"),
    require => Package["drbd"],
    notify  => Service["drbd"],
  }

  iptables { "allow drbd from $host1":
    proto  => "tcp",
    dport  => $port,
    source => $host1_ip,
    jump   => "ACCEPT",
  }

  iptables { "allow drbd from $host2":
    proto  => "tcp",
    dport  => $port,
    source => $host2_ip,
    jump   => "ACCEPT",
  }

}

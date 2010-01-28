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

  # Notifying the drbd service is definitely a bad idea. This exec will do the
  # same thing "service drbd reload" would do.
  exec { "reload drbd":
    command     => "drbdadm adjust all",
    refreshonly => true,
    require     => Service["drbd"],
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
    notify  => Exec["reload drbd"],
  }

  # only allow files managed by puppet in this directory.
  file { "/etc/drbd.conf.d/":
    ensure  => directory,
    source  => "puppet:///drbd/drbd.conf.d/",
    purge   => true,
    recurse => true,
    force   => true,
    require => Package["drbd"],
    notify  => Exec["reload drbd"],
  }

}

/*

== Definition: drbd::config

Drop simple configuration snippets in /etc/drbd.conf.d/

Parameters:
- *$name*: the name of the configuration file.
- *$content*: the configuration parameters to add to this file.

Example usage:

  include drbd::base

  drbd::config { "sync-rate":
    content => "common { syncer { rate 550M; } }",
  }


See also:
 - http://www.drbd.org/users-guide/
 - drbd.conf(5)

*/
define drbd::config ($content) {

  file { "/etc/drbd.conf.d/${name}.conf":
    mode    => "0600",
    owner   => "root",
    content => "# file managed by puppet\n\n${content}\n",
    require => Package["drbd"],
    notify  => Exec["reload drbd"],
  }

}

/*

== Definition: drbd::resource

Wrapper around drbd::config to ease the definition of DRBD resources.

Parameters:
- *$name*: name of the resource.
- *$host1*: one of the host's name
- *$host2*: the other hosts's name
- *$ip1*: $host1's IP address
- *$ip2*: $host2's IP address
- *$port*: the port used to communicate between the two nodes. Defaults to
  7789.
- *$secret*: a shared secret string.
- *$disk*: device to use as DRBD's low-level device.
- *$device*: name of the device defined by the current resource. Defaults to
  /dev/drbd0.
- *$protocol*: protocol identifier for this resource (A, B or C). Defaults to
  C.

Example usage:

  include drbd::base

  drbd::resource { "my-drbd-volume":
    host1  => "bob.example.com",
    host2  => "alice.example.com",
    ip1    => "192.168.1.10", # bob's IP
    ip2    => "192.168.1.11", # alice's IP
    disk   => "/dev/vg0/my-drbd-lv",
    secret => "foobar",
  }

See also:
 - http://www.drbd.org/users-guide/
 - drbd.conf(5)

*/
define drbd::resource ($host1, $host2, $ip1, $ip2, $port='7789', $secret, $disk, $device='/dev/drbd0', $protocol='C') {

  drbd::config { "ZZZ-resource-${name}":
    content => template("drbd/drbd.conf.erb"),
  }

  iptables { "allow drbd from $host1":
    proto  => "tcp",
    dport  => $port,
    source => $ip1,
    jump   => "ACCEPT",
  }

  iptables { "allow drbd from $host2":
    proto  => "tcp",
    dport  => $port,
    source => $ip2,
    jump   => "ACCEPT",
  }

}


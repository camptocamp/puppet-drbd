/*

== Definition: drbd::resource

Wrapper around drbd::config to ease the definition of DRBD resources. It also
initalizes the DRBD device if needed.

Note: you will still need to manually synchronize both DRBD volumes, format
the resulting device and mount it. This can be done with the following
commands:

  drbdadm -- --overwrite-data-of-peer primary $name
  mkfs.ext3 /dev/drbd/by-res/$name
  mount /dev/drbd/by-res/$name /mnt/

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
- *$manage*: whether this DRBD resource must be activated by puppet, if it
  happens to be down. Defaults to "true".

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
define drbd::resource ($host1, $host2, $ip1, $ip2, $port='7789', $secret, $disk, $device='/dev/drbd0', $protocol='C', $manage='true') {

  drbd::config { "ZZZ-resource-${name}":
    content => template("drbd/drbd.conf.erb"),
  }

  if $manage == 'true' {

    # create metadata on device, except if resource seems already initalized.
    exec { "intialize DRBD metadata for $name":
      command => "drbdadm create-md $name",
      onlyif  => "test -e $disk",
      unless  => "drbdadm dump-md $name || (drbdadm cstate $name | egrep -q '^(Sync|Connected)')",
      before  => Service["drbd"],
      require => [
        Exec["load drbd module"],
        Drbd::Config["ZZZ-resource-${name}"],
      ],
    }

    exec { "enable DRBD resource $name":
      command => "drbdadm up $name",
      onlyif  => "drbdadm dstate $name | egrep -q '^Diskless/|^Unconfigured'",
      before  => Service["drbd"],
      require => [
        Exec["intialize DRBD metadata for $name"],
        Exec["load drbd module"],
      ],
    }

  }

  iptables { "allow drbd from $host1 on port $port":
    proto  => "tcp",
    dport  => $port,
    source => $ip1,
    jump   => "ACCEPT",
  }

  iptables { "allow drbd from $host2 on port $port":
    proto  => "tcp",
    dport  => $port,
    source => $ip2,
    jump   => "ACCEPT",
  }

}

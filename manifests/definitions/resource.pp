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

/*

== Definition: drbd::lvm

Simple wrapper around lvcreate to create an LVM logical volume.

Parameters:
- *$name*: resource name. The logical volume will be named "drbd-$name".
- *$vg*: volume group name.
- *$size*: initial size of the logical volume.

Example usage:

  # will create /dev/vg0/drbd-test
  drbd::lvm { "test":
    vg   => "vg0",
    size => "10G",
  }

*/
define drbd::lvm ($vg, $size) {

  exec { "create LVM volume $name":
    command => "lvcreate -L $size -n drbd-${name} $vg",
    creates => "/dev/${vg}/drbd-${name}",
  }
}

# == Class: etherpad_lite
#
# Class to install etherpad lite. Puppet acts a lot like a package manager
# through this class.
#
# To use etherpad lite you will want the following includes:
# include etherpad_lite
# include etherpad_lite::mysql # necessary to use mysql as the backend
# include etherpad_lite::site # configures etherpad lite instance
# include etherpad_lite::apache # will add reverse proxy on localhost
# The defaults for all the classes should just work (tm)
#
#
class etherpad_lite (
  $base_install_dir = '/var/www',
  $base_log_dir     = '/var/log',
  $ep_ensure        = 'present',
  $ep_user          = 'eplite',
  $eplite_version   = 'develop',
) {

  # where the modules are, needed to easily install modules later
  $modules_dir = "${base_install_dir}/etherpad-lite/node_modules"
  $path = "/usr/local/bin:/usr/bin:/bin:${base_install_dir}/etherpad-lite"

  user { $ep_user:
    shell   => '/usr/sbin/nologin',
    home    => "${base_log_dir}/${ep_user}",
    system  => true,
    gid     => $ep_user,
    require => Group[$ep_user],
  }

  group { $ep_user:
    ensure => present,
  }

  # Below is what happens when you treat puppet as a package manager.
  # This is probably bad, but it works and you don't need to roll .debs.
  file { $base_install_dir:
    ensure => directory,
    group  => $ep_user,
    mode   => '0664',
  }

  package { 'abiword':
    ensure => present,
  }

  package { 'curl':
    ensure => present,
  }

  file { '/usr/local/bin/node':
    ensure  => link,
    target  => '/usr/bin/nodejs',
    before  => Anchor['nodejs-anchor'],
  }

  anchor { 'nodejs-anchor': }

  vcsrepo { "${base_install_dir}/etherpad-lite":
    ensure   => $ep_ensure,
    provider => git,
    source   => 'https://github.com/ether/etherpad-lite.git',
    owner    => $ep_user,
    revision => $eplite_version,
    require  => [
        User[$ep_user],
    ],
  }

  exec { 'install_etherpad_dependencies':
    command     => './bin/installDeps.sh',
    path        => $path,
    user        => $ep_user,
    cwd         => "${base_install_dir}/etherpad-lite",
    environment => "HOME=${base_log_dir}/${ep_user}",
    require     => [
      Package['curl'],
      Vcsrepo["${base_install_dir}/etherpad-lite"],
      Anchor['nodejs-anchor'],
    ],
    before      => File["${base_install_dir}/etherpad-lite/settings.json"],
    creates     => "${base_install_dir}/etherpad-lite/node_modules",
  }

  systemd::unit_file { 'etherpad-lite.service':
      source => 'puppet:///modules/etherpad_lite/etherpad-lite.service',
  }

  file { "${base_log_dir}/${ep_user}":
    ensure => directory,
    owner  => $ep_user,
  }
  # end package management ugliness
}

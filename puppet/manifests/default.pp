#add to path so can use apt-get
Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

#updte the system and install build essentials
class system-update {

    exec { 'apt-get update':
        command => 'apt-get update',
    }

    $sysPackages = [ "build-essential" ]

    package { $sysPackages:
        ensure => "installed",
        require => Exec['apt-get update'],
    }
}

#install packages for development
#TODO consider ommiting on live server
class dev-packages {

    $devPackages = [ "vim", "git", "curl", "capistrano"]

    package { $devPackages:
        ensure => "installed",
        require => Exec['apt-get update'],
    }

    exec { 'install capistrano_rsync_with_remote_cache using RubyGems':
        command => 'gem install capistrano_rsync_with_remote_cache',
        require => Package["capistrano"],
    }
    
}

class nginx-setup {
    
    package { "nginx":
        ensure => installed,
        require => Package["build-essential"]
    }

    #start automatically at system bootup
    service { "nginx":
        require => Package["nginx"],
        ensure => running,
        enable => true
    }

    #nginx config file in sites-available
    file { '/etc/nginx/sites-available/default':
        require => Package["nginx"],
        ensure => file,
        source => '/vagrant/files/nginx/default',
        notify => Service["nginx"],
        owner  => root,
        group  => root,
        mode   => 644,
    }

    #symbolic link to config file in sites-enabled to turn it on
    file { "/etc/nginx/sites-enabled/default":
        require => [
            Package["nginx"],
            File["/etc/nginx/sites-available/default"],
        ],
        notify => Service["nginx"],
        ensure => link,
        target => "/etc/nginx/sites-available/default",
        owner => root
    }
}

class mysql-setup {
    class { "mysql":
        root_password => 'auto',          
    }
   

    #TODO change db and password on live server
    mysql::grant { 'wordpress':
        mysql_privileges => 'ALL',
        mysql_password => 'wordpress-vagrant',
        mysql_db => 'wordpress',
        mysql_user => 'wordpress',
        mysql_host => 'localhost',
    }
    
}

#include all the classes
include system-update
include dev-packages
include nginx-setup
include mysql-setup

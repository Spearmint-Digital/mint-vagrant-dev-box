#add to path so can use apt-get
Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

#update the system and install build essentials
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

    $devPackages = [ "vim", "git", "capistrano"]

    package { $devPackages:
        ensure => "installed",
        require => Exec['apt-get update'],
    }

    #get rid of the ruby on rails stuff
    exec { 'install railsless-deploy using RubyGems':
        command => 'gem install railsless-deploy',
        require => Package["capistrano"],
    }

    #for multi-stage deploy (eg. staging, development)
    exec { 'install capistrano-ext using RubyGems':
        command => 'gem install capistrano-ext',
        require => Package["capistrano"],
    }
}

#install a software firewall
class ufw-setup {
  package { 'ufw':
    ensure => present,
  }

  Package['ufw'] -> Exec['ufw allow http'] -> Exec['ufw allow http'] -> Exec['ufw enable']    
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
        source => '/vagrant/conf/nginx/default',
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

    #make sure the www folder is writable by nginx
    file { '/vagrant/www':
        require => Package["nginx"],
        ensure  => 'present',
        mode    => '0755',
        owner   => 'www-data',
        group   => 'www-data', 
        notify => Service["nginx"],
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

class php-setup {
    #install php and its siblings
    $php = ["php5", "php5-fpm", "php-pear", "php5-common", "php5-mcrypt", "php5-mysql", "php5-cli", "php5-gd", "php-apc"]

    package { $php:
        notify => Service['php5-fpm'],
        ensure => latest,
    }
    
    #run php5-fpm
    service { "php5-fpm":
        ensure => running,
        require => Package["php5-fpm"],
    }
  
    #set php config file (for timezones, short open tags)
    file { "/etc/php5/conf.d/custom.ini":
        require => Package["php5-fpm"],
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/php/conf.d/php.ini",
        notify => Service['php5-fpm'],
    }

    #setup php config file to tell php how to serve our data
    file { "/etc/php5/fpm/pool.d/www.conf":
        require => Package["php5-fpm"],
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/php/fpm/pool.d/www.conf",
        notify => Service['php5-fpm'],
    }
}

#run apt-get update every time the apt module is run
class {'apt':
  always_apt_update => true,
}

#every time a package command is executed, the dependency ('apt-get update') will be triggered first.
Exec["apt-get update"] -> Package <| |>


#include all the classes
include system-update
include dev-packages
include nginx-setup
include mysql-setup
include php-setup

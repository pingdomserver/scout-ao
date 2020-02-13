# PSM -> AppOptics migration toolset

This repository provides a toolset for migrating from PSM/Scout to AppOptics/SolarWinds Snap Agent infrastructure monitoring.
Migration needs to be performed on each monitored server.

## Table of contents

1. [Prerequisites](#prerequisites)
	- [Upgrading from cron-based agent to scoutd](#upgrade-cron-based-agent-to-scoutd)
	- [Upgrade scoutd](#upgrade-scoutd)
	- [Upgrade AppOptics Host Agent to SolarWinds Snap Agent](#upgrade-appoptics-host-agent-to-solarwinds-snap-agent)
2. [Migration](#migration-script)
	- [Basic](#basic)
	- [Advanced concepts](#advanced-concepts)
	- [Using configuration management](#using-configuration-management)
		- [Ansible](#ansible)
		- [Chef](#chef)
		- [Puppet](#puppet)
3. [SolarWinds Snap Agent configuration](#solarwinds-snap-agent-configuration)
4. [Further reading](#further-reading)


## Prerequisites

### Upgrade cron-based scout to scoutd

If not done already, you need to upgrade your cron-based scout installation to the newest version.
For detailed instructions please refer to: https://server-monitor.readme.io/docs/agent#upgrading-to-scoutd

### Upgrade scoutd

If not done already, you need to update scout to the latest version.
For detailed instructions please refer to: https://server-monitor.readme.io/docs/agent#section-updating-scoutd-to-the-latest-version

### Upgrade AppOptics Host Agent to SolarWinds Snap Agent

You need to be an active SolarWinds AppOptics user with the newest SolarWinds Snap Agent installed.
For detailed instructions please refer to: https://docs.appoptics.com/kb/host_infrastructure/host_agent_upgrade

## Migration script

### Basic

Just run the following command:

	$ sudo ./migrate.rb

And then enable the PSM integration in the AppOptics UI. On the [Integrations Page](https://my.appoptics.com/infrastructure/integrations) you should see the PSM plugin available in a few minutes.

### Advanced concepts

Normally you won't need to change those options.
When you're sure about this, the migration toolset comes with the following options:

  * `--no-plugins`
skip downloading PSM plugins
Note: When choosing this option, you need to manually provide them for the Snap PSM collector plugin. The default location is `/opt/SolarWinds/Snap/bin/psm` (but can be altered in the PSM collector plugin config file).

  * `--no-config`
skip SolarWinds Snap Agent configuration
Note: When choosing this option, you need to manually configure the Snap PSM collector plugin. For the detailed configuration information, please refer to https://docs.appoptics.com/kb/host_infrastructure/integrations/psm/

### Using configuration management

#### Ansible
```
# Checkout git repository
- git:
  repo: git@github.com:pingdomserver/scout-ao.git
  dest: /tmp/pingdomserver/scout-ao

# Run migration script
- name: run AO migration script
  command: ruby /tmp/pingdomserver/scout-ao/migrate.rb
  become: true
```
#### Chef
```
# Checkout git repository
git '/tmp/pingdomserver/scout-ao' do
  repository 'git@github.com:pingdomserver/scout-ao.git'
  revision 'master'
  action :sync
end

# Run migration script
execute 'run AO migration script' do
  command 'ruby /tmp/pingdomserver/scout-ao/migrate.rb'
end
```
#### Puppet
```
# Checkout git repository
vcsrepo { '/tmp/pingdomserver/scout-ao':
  ensure   => present,
  provider => git,
  source   => 'git@github.com:pingdomserver/scout-ao.git',
}

# Run migration script
exec { 'run AO migration script':
  command => 'ruby /tmp/pingdomserver/scout-ao/migrate.rb'
}
```

## SolarWinds Snap Agent agent configuration

You need to enable collector(s) on AppOpctics website:
* PSM plugins/scripts: https://my.appoptics.com/infrastructure/integrations/psm
* StatsD: https://my.appoptics.com/infrastructure/integrations/statsd

## Further reading

* [PSM docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/psm)
* [StatsD docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/tested/statsd)

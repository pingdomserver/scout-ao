# PSM -> AppOptics migration toolset

This repository provides a helper toolset for performing migration from PSM/Scout to AppOptics/Snap monitoring system. 
Migration needs to be performed on each monitored server.

## Prerequisities

### Upgrade cron-based scout to scoutD

If not done already, you need to upgrade your cron-based scout installation to the newest version.
For detailed instructions please refer to: https://server-monitor.readme.io/docs/agent#upgrading-to-scoutd

### Update scout/scoutD

If not done already, you need to update scout to the latest version.
For detailed instructions please refer to: https://server-monitor.readme.io/docs/agent#section-updating-scoutd-to-the-latest-version

### Upgrade AppOptics Host Agent to SolarWinds Snap Agent

You need to be an active SolarWinds AppOptics user with the newest SolarWinds Snap Agent installed.
For detailed instructions please refer to: https://docs.appoptics.com/kb/host_infrastructure/host_agent_upgrade

## Migration script

### Easy

Just run the following command:

	sudo ./migrate.rb

And then enable the PSM integration in the AppOptics UI - on the [Integrations Page](https://my.appoptics.com/infrastructure/integrations) you should see the PSM plugin available in a few minutes.

### Advanced

Normally you won't need to change those options. 
When you're sure about this, the migration toolset comes with the following options:

  * `--no-plugins`
skip downloading PSM plugins
Note: When choosing this option, you need to manually provide them for the Snap PSM collector plugin. The default location is `/opt/SolarWinds/Snap/bin/psm` (but can be altered in the PSM collector plugin config file).

  * `--no-config`
skip Snap Agent configuration 
Note: When choosing this option, you need to manually configure the Snap PSM collector plugin. For the detailed configuration information, please refer to https://docs.appoptics.com/kb/host_infrastructure/integrations/psm/

## Metrics receiving

You need to enable collector(s) on AppOpctics website:
* PSM plugins/scripts: https://my.appoptics.com/infrastructure/integrations/psm
* StatsD: https://my.appoptics.com/infrastructure/integrations/statsd

## Further reading

* [PSM docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/psm)
* [StatsD docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/tested/statsd)
# PSM -> AppOptics migration toolset

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

## Migration

### Easy

Run the following command:

	sudo ./migrate.rb

### Advanced

Normally you won't need to change those options. 
When you're sure about this, the migration toolset comes with the following options:

  * `--no-plugins`
skip downloading PSM plugins
Note: When choosing this option, you need to manually provide them for the Snap PSM collector plugin

  * `--no-config`
skip Snap Agent configuration 
Note: When choosing this option, you need to manually configure the Snap PSM collector plugin. For the detailed configuration information, please refer to https://docs.appoptics.com/kb/host_infrastructure/integrations/psm/

##  


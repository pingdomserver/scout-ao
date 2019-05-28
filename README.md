# PSM -> AppOptics migration toolset

Migration needs to be performed on each monitored server.

## Prerequisities

### Upgrade cron-based scout to scoutD

If not done already, you need to upgrade your cron-based scout installation to the newest version.
For detailed instructions please refer to: https://server-monitor.readme.io/docs/agent#upgrading-to-scoutd

### Update scout

If not done already, you need to update scout to the latest version.
For detailed instructions please refer to: https://server-monitor.readme.io/docs/agent#section-updating-scoutd-to-the-latest-version

### Install SolarWinds Snap Agent

You need to be an active SolarWinds AppOptics user with SolarWinds Snap Agent installed.
For detailed instructions please refer to: https://docs.appoptics.com/kb/host_infrastructure/host_agent/#solarwinds-snap-agent-linux

## Migration

### Easy

Run the following command:

	sudo ./bin/runner

### Advanced

Normally you won't need to change those options. 
When you're sure about this, the migration toolset comes with the following options:

  * `--no-plugins`
skip downloading PSM plugins
  * `--no-config`
skip Snap Agent configuration
  * `--no-gems`
skip copying gems (server_metrics, scout-client) from package dir

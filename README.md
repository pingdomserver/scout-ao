## Quick start
The installation needs to be run on the target server using the following command:

	sudo ./bin/runner <appoptics_token> [--options]

## Customization
If needed, custom behavior can have the following options:

  * `--copy-psm-plugin`
replace the psm collector plugin binary installed with the snap plugin, with the one provided in the migration installer
  * `--no-plugin`
skip plugins from API
  * `--no-agent`
skip AO agent installation
  * `--no-ao-config`
skip AO configuration generation
  * `--no-config`
skip configuration - do not generate/overwrite the following files:
    * `/opt/appoptics/etc/plugins.d/psm.yaml`
    * `/opt/appoptics/etc/tasks.d/task-psm.yaml`
    * `/opt/appoptics/etc/tasks.d/task-bridge-statsd.yaml`
    * `/opt/appoptics/etc/plugins.d/statsd.yaml`
    * `/opt/appoptics/etc/config.yaml`
  * `--no-gems`
skip copying gems (server_metrics, scout-client) from package dir
  * `--no-statsd`
skip statsd config:
    * `/opt/appoptics/etc/tasks.d/task-bridge-statsd.yaml`
    * `/opt/appoptics/etc/plugins.d/statsd.yaml`

Note: `token` param is not required when both `--no-agent` and `--no-ao-config` are set.

## Installation steps
  * stops `appoptics-snapteld` service (if any)
  * stops `scoutd` (so the data forwarding would stop submitting to AppOptics here too)
  * installs the `appoptics-snap agent` (using the official AppOptics agent installer (`appoptics-host-agent-installer.sh`) v1.0.0 with some modifications)
  * installs `server-metrics` 1.2.18
  * installs `scout-client` 6.4.5
downloads ruby plugins (to /opt/appoptics/opt/psm/) using the API call to PSM
  * configures appoptics agent:
    * `/opt/appoptics/tasks.d/task-psm.yaml`
      * tags:
         * `roles` (using API call to PSM) (if set)
         * `environment` (from scoutd config) (if set or set to production if it’s not present in scoutd.yml)
         * `hostname` (from scoutd config) (if set)
    * `/opt/appoptics/tasks.d/task-statsd.yaml`
      * tags:
         * `roles` (using API call to PSM)
         * `environment` (from scoutd config or set to production if it’s not present in scoutd.yml)
         * `hostname` (from scoutd config)
    * `/opt/appoptics/plugins.d/psm.yaml`
      * `account_key` (PSM key)
      * `environment` (from scoutd config or set to production if it’s not present in scoutd.yml)
      * `hostname` (from scoutd config)
      * `agent_ruby_bin` (path to scout client binary)
      * `roles` (using API call to PSM)
      * `key_processes` (using API call to PSM, comma-separated words list)
      * `plugin_directory` (always /opt/appoptics/opt/psm)
    * `/opt/appoptics/etc/config.yaml`
      * `token`
      * `hostname_alias` (if hostname was set in scoutd.yml config)

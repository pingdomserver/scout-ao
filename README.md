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

## Migration

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

### Manual

#### Assure prerequisites

1. Make sure you have [upgraded from cron-based agent to scoutd](#upgrade-cron-based-agent-to-scoutd)

0. Stop the ScoutD service 
    ```shell script
    SCOUTD_PID=$(pgrep scoutd)
    
    # Stop the service
    scoutctl stop
    
    # Make sure the process have exited
    pgrep -g ${SCOUTD_PID} | xargs kill
    ```

0. Backup Scout "history file":

    ```shell script
    HISTORY_FILE="/var/lib/scoutd/client_history.yaml"
    [ -f #{HISTORY_FILE} ] && mv -f #{HISTORY_FILE} #{HISTORY_FILE}.bak
    ```

0. Download PSM plugins

    TODO: Document PSM plugins downloading

0. Set permissions

    ```shell script
    # swisnap is run as solarwinds user which now needs to be in scoutd group
    # for the psm collector running scout collector
    usermod -a -G scoutd solarwinds

    # Let the group write to scout realm 
    chmod -v g+rw /var/log/scout/scoutd.log
    chmod -Rv g+w /var/lib/scoutd
    ```

0. Stop SWISnap

    ```shell script
    service swisnapd stop
    ```

0. Configure SWISnap PSM plugin

    Edit the following plugin config template and save as /opt/SolarWinds/Snap/etc/plugins.d/psm.yaml
    ```yaml
    ---
    collector:
      psm:
        all:
          ## Path to Ruby interpreter executable 
          ruby_path: "/usr/bin/ruby"

          ## Path to scout-client executable
          agent_ruby_bin: "/usr/share/scout/ruby/scout-client/bin/scout"

          ## Path to the directory with .rb files and settings for plugins
          ## All PSM plugins should be downloaded to that directory
          plugin_directory: "/opt/SolarWinds/Snap/psm" 

          ## Path to the ScoutD agent data file
          agent_data_file: "/var/lib/scoutd/client_history.yaml" 
    
    ## Autoload directive and settings
    load:
      plugin: snap-plugin-collector-psm
      task: task-psm.yaml
    
    ```

    Edit the following task template and save as /opt/SolarWinds/Snap/etc/tasks.d/task-psm.yaml
    ```yaml
    ---
    version: 1
    
    schedule:
      type: cron
      interval: "0 * * * * *"
    
    workflow:
      collect:
        metrics:    
          # Don't change, filtering is not yet supported for psm collector
          /psm/*: {}
        ## Set if needed - those tags will be applied to *every* metric matching /psm/*
        tags:
          /:
            #roles: 
            #environment:
            #hostname:
        publish:
          - plugin_name: publisher-appoptics

    ```

0. If you were using StatsD feature in PSM, you also need to enable StatsD collector for SWISnap
   
   Edit the following plugin config template and save as /opt/SolarWinds/Snap/etc/plugins.d/psm-statsd.yaml
   ```yaml
    ---    
    collector:
      # The statsd plugin runs a backgrounded statsd listener service.
      statsd:
        all:
          ## Protocol, must be "tcp" or "udp" (default=udp)
          protocol: "udp"
    
          ## MaxTCPConnection - applicable when protocol is set to tcp (default=250)
          # max_tcp_connections: 250
    
          ## Address and port to host UDP listener on (default=":8125")
          service_address: ":8125"
    
          ## The following configuration options control when the plugin clears its cache
          ## of previous values. If set to false, then the plugin will only clear its
          ## cache when the daemon is restarted.
          ## Reset gauges every interval (default=true)
          # delete_gauges: true
          ## Reset counters every interval (default=true)
          # delete_counters: true
          ## Reset sets every interval (default=true)
          # delete_sets: true
          ## Reset timings & histograms every interval (default=true)
          # delete_timings: true
    
          ## Percentiles to calculate for timing & histogram stats
          # percentiles: "50,90,95,99"
    
          ## separator to use between elements of a statsd metric (default="_")
          metric_separator: "."
    
          ## Parses tags in the datadog statsd format (default=false)
          # parse_data_dog_tags: false
    
          ## Templates specify rules for translating metric names into tagged metrics. For more details:
          ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_INPUT.md#graphite
          # templates: |
          #   cpu.* measurement*
    
          ## Number of UDP messages allowed to queue up, once filled,
          ## the statsd server will start dropping packets (default=10000)
          # allowed_pending_messages: 10000
    
          ## Number of timing/histogram values to track per-measurement in the
          ## calculation of percentiles. Raising this limit increases the accuracy
          ## of percentiles but also increases the memory usage and cpu time. (default=1000)
          # percentile_limit: 1000
    
          ## Maximum socket buffer size in bytes, once the buffer fills up, metrics
          ## will start dropping.  Defaults to the OS default.
          # read_buffer_size: 65535
    
          ## Metric name prefix
          # bridge_prefix: "statsd"
          # bridge_prefix: ""
    
    load:
      plugin: snap-plugin-collector-bridge-statsd
      task: task-bridge-statsd.yaml
    ```

    Edit the following task template and save as /opt/SolarWinds/Snap/etc/tasks.d/task-psm-statsd.yaml
    ```yaml
    ---
    version: 1

    schedule:
      # Run every minute
      type: cron
      interval: "0 * * * * *"

    workflow:
      collect:
        metrics:
          /statsd/*/all: {}
        config:
          /statsd/*/all:
            # Report min, max, sum, count, stddev as a single measurement to the publisher
            bridge_use_json_fields: true
        tags:
          /:
            #roles: 
            #environment:
            #hostname:
        publish:
          - plugin_name: publisher-appoptics
    
    ```

0. Restart SWISnap
    (example for SysV-init)
    ```shell script
    service swisnapd restart
    ```

0. As the very last step, you need to enable collector(s) on AppOpctics website:
    * PSM plugins/scripts: https://my.appoptics.com/infrastructure/integrations/psm
    * StatsD: https://my.appoptics.com/infrastructure/integrations/statsd

## Further reading

* [PSM docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/psm)
* [StatsD docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/tested/statsd)

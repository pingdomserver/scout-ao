# PSM -> AppOptics migration toolset

This repository provides a toolset for migrating from PSM/Scout to AppOptics/SolarWinds Snap Agent infrastructure monitoring.
Migration needs to be performed on each monitored server.

## Table of contents

- [PSM -> AppOptics migration toolset](#psm---appoptics-migration-toolset)
  - [Table of contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [Upgrade cron-based scout to scoutd](#upgrade-cron-based-scout-to-scoutd)
    - [Upgrade scoutd](#upgrade-scoutd)
    - [Upgrade AppOptics Host Agent to SolarWinds Snap Agent](#upgrade-appoptics-host-agent-to-solarwinds-snap-agent)
  - [Migration](#migration)
    - [Basic](#basic)
    - [Advanced concepts](#advanced-concepts)
    - [Using configuration management](#using-configuration-management)
    - [Manual](#manual)
  - [Further reading](#further-reading)

## Prerequisites

The latest Scout agent and SolarWinds Snap Agent need to be installed.
Once the migration is complete, the ScoutD daemon can be disabled, but the dependencies of the Scout agent are still needed for Scout plugins to be executed by the SolarWinds Snap Agent.

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

A concept for the migration steps is to replace the long-living ScoutD daemon process that periodically calls scout-client with the SWISnap service (which will do the same but in much more effective and configurable way).

Scout-client is a poller/collector that loops over all the Ruby plugins. When used with ScoutD, it not only runs the plugins scripts but also asks PSM API for them every time. It also asks for configuration changes (new scripts or host attributes). 
After the migration, the PSM account key (API token) will no longer be used as all the needed plugins are downloaded and saved locally along with their configuration files.  

Follow the steps as described below (in that order) to perform a migration manually on your host.

#### Deactivate ScoutD

1. Make sure you have [upgraded from cron-based agent to scoutd](#upgrade-cron-based-agent-to-scoutd)

0. Stop the ScoutD service 
    ```shell script
    SCOUTD_PID=$(pgrep scoutd)
    
    # Stop the service
    scoutctl stop
    
    # Give it a while and make sure the process has exited
    sleep 5
    pgrep -g ${SCOUTD_PID} | xargs kill
    ```

#### Backup

1. Backup the "history file" of Scout - ie. a config/data file that contains your PSM token along with some other data:

    ```shell script
    HISTORY_FILE="/var/lib/scoutd/client_history.yaml"
    [ -f #{HISTORY_FILE} ] && mv -f #{HISTORY_FILE} #{HISTORY_FILE}.bak
    ```

#### Prepare data

1. Download PSM plugins

    Make the directory first (can be any location, however if you change that, make sure to update all the other relevant places)
    ```shell script
    sudo mkdir -p /opt/SolarWinds/Snap/psm
    sudo chown -R solarwinds:solarwinds /opt/SolarWinds/Snap/psm
    ```

    Unless you want to use the PSM API client and downloader parts of the migration script (see https://github.com/pingdomserver/scout-ao/tree/master/lib/scout), you have to do the API requests and parsing manually for each server (host):

    NOTE: You can easily obtain `hostname` and `key` from the ${HISTORY_FILE} you have backed up earlier.

    1. Fetch roles
    
        ```shell script
        curl "http://server.pingdom.com/api/v2/account/clients/roles?hostname=${HOSTNAME}&key=${ACCOUNT_KEY}"
        ```
    
        Sample response:
        
        ```json
        [
            {
                "id": 123456,
                "name": "All Servers"
            },
            {
                "id": 234567,
                "name": "database"
            }
        ]
        ```
    
        NOTE: Every host would have "All Servers" entry, some of them may have additional one(s).
    
    0. Fetch environments
    
        ```shell script
        curl "http://server.pingdom.com/api/v2/account/clients/environment?hostname=${HOSTNAME}&key=${ACCOUNT_KEY}"
        ```

        Sample response:
        
        ```json
        {
            "id": 12345,
            "name": "staging"
        }
        ```

    0. Fetch plugins code (and configuration if applicable)

        ```shell script 
        curl "http://server.pingdom.com/api/v2/account/clients/plugins?hostname=${HOSTNAME}&key=${ACCOUNT_KEY}"
        ```

        Sample response:
        
        ```json
        [
            {
                "code": "class NetworkConnections < Scout::Plugin\n\n  OPTIONS=<<-EOS\n    port:\n      label: Ports\n      notes: comma-delimited list of ports to monitor. Or specify all for summary info across all ports.\n      default: \"80,443,25\"\n  EOS\n\n  def build_report\n    report_hash={}\n    port_hash = {}\n    if option(:port).strip != \"all\"\n      option(:port).split(/[, ]+/).each { |port| port_hash[port.to_i] = 0 }\n    end\n\n    lines = shell(\"netstat -n\").split(\"\\n\")\n    connections_hash = {:tcp => 0,\n                        :udp => 0,\n                        :unix => 0,\n                        :total => 0}\n\n    lines.each { |line|\n      line = line.squeeze(\" \").split(\" \")\n      next unless line[0] =~ /tcp|udp|unix/\n      connections_hash[:total] += 1\n      protocol = line[0].sub(/\\d+/,'').to_sym\n      connections_hash[protocol] += 1 if connections_hash[protocol]\n\n      local_address = line[3].sub(\"::ffff:\",\"\") # indicates ip6 - remove so regex works\n      port = local_address.split(\":\")[1].to_i\n      port_hash[port] += 1 if port_hash.has_key?(port)\n    }\n\n    connections_hash.each_pair { |conn_type, counter|\n      report_hash[conn_type]=counter\n    }\n\n    port_hash.each_pair { |port, counter|\n      report_hash[\"Port #{port}\"] = counter\n    }\n\n    report(report_hash)\n  end\n\n  # Use this instead of backticks. It's a separate method so it can be stubbed for tests\n  def shell(cmd)\n    `#{cmd}`\n  end\nend",
                "file_name": "Network connections",
                "id": 123456789,
                "meta": {
                    "options": {
                        "port": {
                            "default": "80,443,25",
                            "label": "Ports",
                            "notes": "comma-delimited list of ports to monitor. Or specify all for summary info across all ports.",
                            "value": "80,443,25,22,53"
                        }
                    }
                },
                "name": "Network connections"
            }
        ]
        ```
       
        Contents of `.code` should be saved as a `.rb` file, contents of `.meta.options` as `.yaml`. Both files should have the same name (no special naming rules here).

0. Update permissions for running scout stuff from a snap plugin

    ```shell script
    # swisnap is run as solarwinds user which now needs to be in scoutd group
    # for the psm collector running scout collector
    usermod -a -G scoutd solarwinds

    # Let the group write to scout realm 
    chmod -v g+rw /var/log/scout/scoutd.log
    chmod -Rv g+w /var/lib/scoutd
    ```

#### Setup SolarWinds Snap Agent

1. Configure PSM plugin

    Adjust the following plugin configuration template and save it as `/opt/SolarWinds/Snap/etc/plugins.d/psm.yaml`
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

    Adjust the following task configuration and save it as `/opt/SolarWinds/Snap/etc/tasks.d/task-psm.yaml`
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
          #/:
            #roles: 
            #environment:
            #hostname:
        publish:
          - plugin_name: publisher-appoptics

    ```

0. If you were using StatsD feature in PSM, you also need to enable StatsD collector for SWISnap
   
   Adjust the following plugin configuration template and save it as `/opt/SolarWinds/Snap/etc/plugins.d/psm-statsd.yaml`
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

    Adjust the following task configuration and save it as `/opt/SolarWinds/Snap/etc/tasks.d/task-psm-statsd.yaml`
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
          #/:
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

#### Enable plugins in AppOptics UI

1. As the very last step, you need to enable collector(s) on AppOpctics website:
    * PSM plugins/scripts: https://my.appoptics.com/infrastructure/integrations/psm
    * StatsD: https://my.appoptics.com/infrastructure/integrations/statsd

## Further reading

* [PSM docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/psm)
* [StatsD docs](https://docs.appoptics.com/kb/host_infrastructure/integrations/tested/statsd)

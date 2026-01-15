# Must-Gather Loki

A tool for ingesting and visualizing OpenShift/Kubernetes must-gather logs using Grafana Loki and Promtail.

## Overview

This tool provides a local observability stack that allows you to explore container logs from OpenShift must-gather archives using Grafana's powerful query interface. It runs Grafana, Loki, and Promtail as a unified Podman pod, automatically ingesting and indexing logs for easy searching and analysis.

## Architecture

The stack consists of three containerized components running in a Podman pod:

```
┌─────────────────────────────────────────────────────────────┐
│                        Podman Pod                            │
│                                                              │
│  ┌──────────┐      ┌──────────┐      ┌──────────────────┐  │
│  │ Promtail │─────>│   Loki   │<─────│     Grafana      │  │
│  │          │      │          │      │  (Web UI :3000)  │  │
│  │  Scrapes │      │  Stores  │      │                  │  │
│  │   Logs   │      │   Logs   │      │                  │  │
│  └────┬─────┘      └──────────┘      └──────────────────┘  │
│       │                                                      │
│       │ Reads logs from                                     │
│       ▼                                                      │
│  Must-Gather                                                 │
│  Directory                                                   │
│  (Host mount)                                                │
└─────────────────────────────────────────────────────────────┘
```

### Components

- **Grafana** (Port 3000): Web-based visualization and query interface
- **Loki** (Port 3100): Log aggregation and storage system
- **Promtail**: Log collection agent that scrapes must-gather logs and forwards them to Loki

## Prerequisites

- [Podman](https://podman.io/) installed and running
- An unpacked OpenShift must-gather archive

## Quick Start

1. Extract your must-gather archive:
   ```bash
   tar -xzf must-gather.tar.gz
   ```

2. Run the stack with your must-gather directory:
   ```bash
   ./local-loki.sh /path/to/unpacked/must-gather
   ```

3. Open Grafana in your browser:
   ```
   http://localhost:3000/explore
   ```

4. Start querying your logs using LogQL (Loki's query language)

## How It Works

### 1. Startup Process

When you run `local-loki.sh`:

1. The script takes your must-gather directory path as an argument
2. It replaces `REPLACE_ME` in `grafana-stack-template.yaml` with your actual path
3. It generates `grafana-stack.yaml` with the correct volume mount
4. Podman creates a pod with Grafana, Loki, and Promtail containers

### 2. Log Ingestion

**Promtail** (`promtail/config.yml`):
- Monitors all `current.log` files in the must-gather directory
- Extracts metadata from file paths using regex patterns:
  - Namespace
  - Pod name
  - Container name
- Parses CRI (Container Runtime Interface) formatted logs
- Extracts timestamps and log messages
- Forwards structured logs to Loki with labels

**Path Pattern**: `/logs/**/current.log`

**Extracted Labels**:
- `job`: container-logs
- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name

### 3. Log Storage

**Loki** (`loki/loki-local-config.yaml`):
- Listens on port 3100 for log ingestion
- Stores logs in local filesystem (`./loki/data`)
- Uses BoltDB for indexing
- Configured with high ingestion limits for must-gather processing:
  - 1024 MB ingestion rate
  - Unlimited streams per user
  - 35GB per-stream rate limit

**Note**: This is a development configuration not suitable for production use.

### 4. Visualization

**Grafana** (`grafana/grafana.ini`):
- Web UI accessible at `http://localhost:3000`
- Pre-configured with Loki datasource (`grafana/provisioning/datasources/loki.yaml`)
- Data persisted in `./grafana/data`
- Default credentials: admin/admin

## Querying Logs

### Example Queries

1. **All logs from a specific namespace**:
   ```
   {namespace="openshift-monitoring"}
   ```

2. **Logs from a specific pod**:
   ```
   {pod="prometheus-k8s-0"}
   ```

3. **Filter by container and search for errors**:
   ```
   {namespace="default", container="myapp"} |= "error"
   ```

4. **Regex search for patterns**:
   ```
   {job="container-logs"} |~ "(?i)exception|error|fatal"
   ```

5. **Aggregate and count errors by namespace**:
   ```
   sum by (namespace) (count_over_time({job="container-logs"} |= "error" [5m]))
   ```

## Directory Structure

```
must-gather-loki/
├── grafana/
│   ├── data/                    # Grafana data directory (persisted)
│   ├── grafana.ini              # Grafana configuration
│   └── provisioning/
│       └── datasources/
│           └── loki.yaml        # Loki datasource configuration
├── loki/
│   ├── data/                    # Loki data directory (persisted)
│   └── loki-local-config.yaml   # Loki server configuration
├── promtail/
│   └── config.yml               # Promtail scrape configuration
├── grafana-stack-template.yaml  # Podman pod template
├── local-loki.sh                # Startup script
└── README.md                    # This file
```

## Stopping the Stack

To stop and remove all containers:

```bash
podman pod rm -f grafana-stack-pod
```

## Configuration

### Promtail Configuration

Edit `promtail/config.yml` to customize:
- Log file paths to scrape
- Label extraction patterns
- Pipeline stages for log processing

### Loki Configuration

Edit `loki/loki-local-config.yaml` to customize:
- Storage settings
- Retention policies
- Ingestion rate limits
- Query performance settings

### Grafana Configuration

Edit `grafana/grafana.ini` to customize:
- Authentication settings
- UI preferences
- Server ports
- Database settings

## Troubleshooting

### Logs not appearing in Grafana

1. Check Promtail is running:
   ```bash
   podman pod ps
   ```

2. Verify Promtail can access the must-gather directory:
   ```bash
   podman exec -it <promtail-container-id> ls /logs
   ```

3. Check Promtail logs for errors:
   ```bash
   podman logs <promtail-container-id>
   ```

### Cannot access Grafana

1. Verify port 3000 is not in use:
   ```bash
   lsof -i :3000
   ```

2. Check Grafana container logs:
   ```bash
   podman logs <grafana-container-id>
   ```

### High resource usage

The Loki configuration is optimized for ingesting large must-gather archives. If you experience performance issues:

1. Reduce ingestion limits in `loki/loki-local-config.yaml`
2. Limit the number of concurrent queries
3. Reduce retention period

## Limitations

- This is a local, single-user development setup
- Not suitable for production use
- No authentication enabled by default
- Logs are stored on local filesystem only
- No high availability or replication

## Learn More

- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)

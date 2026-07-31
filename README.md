# ansible-rpi

![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Armbian](https://img.shields.io/badge/Armbian-DD4814?style=flat&logo=armbian&logoColor=white)
![Orange Pi Zero 3](https://img.shields.io/badge/Orange%20Pi%20Zero%203-FF7900?style=flat&logo=orangepi&logoColor=white)
![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?style=flat&logo=pihole&logoColor=white)
![Platform](https://img.shields.io/badge/platform-ARM64-lightgrey?style=flat)

This repository contains Ansible playbooks to provision an Orange Pi Zero 3 running Armbian as a small self-hosted DNS stack. The current implementation installs and configures:

- Pi-hole as a network-wide DNS sinkhole and dashboard
- Unbound as a local recursive resolver listening on localhost
- UFW as a host firewall restricted to the local LAN
- chrony or ntp for time synchronization
- a root crontab for maintenance tasks and periodic updates
- log rotation for Pi-hole logs, temporary directories, and systemd journal settings
- service start/stop/restart helpers for the DNS stack

## Current stack behavior

The deployment is organized around a small set of playbooks and roles:

```text
Clients
  -> Pi-hole on port 53
      -> Unbound on localhost:5335
```

| Component | Role in the stack |
|---|---|
| Pi-hole | DNS filtering and web dashboard |
| Unbound | Recursive validating resolver used by Pi-hole |
| UFW | Firewall policy for SSH, DNS, web UI, and NTP |
| NTP | Time synchronization via chrony or ntp |
| cron | Periodic Pi-hole and system maintenance |

## Requirements

- Ansible 2.12+ on the ansible controller host
- SSH access to the target device
- A remote user with sudo privileges
- Internet access from the target host during installation
- The following collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

The default inventory and configuration are loaded through [ansible.cfg](ansible.cfg).

## Inventory and variables

The current inventory target is defined in [inventory/inventory.ini](inventory/inventory.ini):

```ini
[pihole]
orangepi ansible_host=192.168.10.3 host_interface=end0
```

The relevant variables currently configured are:

| Variable | Current value | Purpose |
|---|---:|---|
| `lan_network` | `192.168.10.0/24` | Source network allowed through UFW |
| `ntp_package` | `chrony` | Selected NTP implementation |
| `ntp_pool` | `south-america.pool.ntp.org` | NTP pool used by the chrony template |
| `pihole_default_webpassword` | `admin` | Pi-hole web UI password (change before exposing the dashboard) |
| `pihole_teleporter_filename` | `pihole_teleporter.zip` | Backup archive name used for Pi-hole imports/exports |
| `pihole_teleporter_vault` | `roles/configure_pihole/files` | Local destination for fetched backups |
| `pihole_teleporter_dest` | `/tmp` | Temporary location used during import/export |
| `pihole_bin_dir` | `/usr/local/bin` | Pi-hole binary directory |
| `pihole_logrotate_config_dir` | `/etc/logrotate.d` | Directory where the Pi-hole logrotate config is installed |
| `pihole_logrotate_config_file` | `pihole` | Logrotate configuration file name |
| `pihole_logrotate_days` | `2` | Number of retained Pi-hole log rotations |
| `tmp_retention_days` | `7` | Retention period for temporary files under `/tmp` |
| `var_tmp_retention_days` | `7` | Retention period for temporary files under `/var/tmp` |
| `systemd_tmpfiles_config_dir` | `/etc/tmpfiles.d` | Directory for tmpfiles.d maintenance rules |
| `systemd_tmpfiles_config_file` | `tmp.conf` | tmpfiles configuration file name |
| `journalctl_config_dir` | `/etc/systemd/journald.conf.d` | Directory for custom journald config |
| `journalctl_config_file` | `00-arm-optimized.conf` | Journald config filename |
| `journalctl_storage` | `volatile` | Journald storage mode |
| `journalctl_max_use` | `32M` | Maximum journald runtime storage size |
| `journalctl_max_file_size` | `8M` | Maximum journald file size |
| `journalctl_compress` | `no` | Journald compression setting |
| `journalctl_rate_limit_interval` | `30s` | Journald rate limit interval |
| `journalctl_rate_limit_burst` | `200` | Journald rate limit burst |
| `journalctl_audit` | `no` | Journald audit logging enabled |
| `journalctl_ForwardToWall` | `no` | Journald forwarding to wall |
| `journalctl_ForwardToSyslog` | `no` | Journald forwarding to syslog |
| `unbound_config_dir` | `/etc/unbound` | Main Unbound configuration directory |

## Common usage

Run the main stack setup:

```bash
ansible-playbook setup_all.yml
```

The current [setup_all.yml](setup_all.yml) imports these playbooks in order:

1. [install_unbound.yml](install_unbound.yml)
2. [install_pihole.yml](install_pihole.yml)
3. [configure_ufw.yml](configure_ufw.yml)

### Individual playbooks

```bash
ansible-playbook install_unbound.yml
ansible-playbook install_pihole.yml
ansible-playbook configure_unbound.yml
ansible-playbook configure_pihole.yml
ansible-playbook configure_ufw.yml
ansible-playbook configure_ntpd.yml
ansible-playbook configure_cron.yml
ansible-playbook configure_log_rotation.yml
```

### Service control

```bash
ansible-playbook start_all.yml
ansible-playbook stop_all.yml
ansible-playbook restart_all.yml
```

### Backup and restore

```bash
ansible-playbook backup_pihole.yml
```

The backup playbook exports a Pi-hole Teleporter archive and fetches it into the local role files directory for later re-import.

## Playbook reference

| Playbook | Current behavior |
|---|---|
| [setup_all.yml](setup_all.yml) | Runs the main Unbound/Pi-hole/UFW bootstrap flow |
| [install_unbound.yml](install_unbound.yml) | Installs Unbound, dnsutils, and the selected NTP package, then applies the Unbound configuration |
| [configure_unbound.yml](configure_unbound.yml) | Writes [roles/configure_unbound/templates/unbound.conf.j2](roles/configure_unbound/templates/unbound.conf.j2), downloads root hints, rebuilds the modular config directory, validates the config with `unbound-checkconf`, and initializes remote control |
| [install_pihole.yml](install_pihole.yml) | Installs Pi-hole unattended, writes the setupVars configuration, runs the official installer, and enables the service |
| [configure_pihole.yml](configure_pihole.yml) | Templates `/etc/hosts`, installs a systemd override for `pihole-FTL.service` so it depends on Unbound, imports the Teleporter archive, and refreshes gravity |
| [configure_ufw.yml](configure_ufw.yml) | Installs UFW and applies LAN-only allow rules for SSH, DNS, dashboard access, and NTP |
| [configure_ntpd.yml](configure_ntpd.yml) | Installs and configures chrony or ntp depending on `ntp_package` |
| [configure_cron.yml](configure_cron.yml) | Installs the maintenance script and replaces the root crontab with the templated schedule |
| [configure_log_rotation.yml](configure_log_rotation.yml) | Deploys logrotate and tmpfiles rules for Pi-hole logs and temporary directory retention |
| [start_all.yml](start_all.yml) | Starts `unbound` and `pihole-FTL` |
| [stop_all.yml](stop_all.yml) | Stops `pihole-FTL` and `unbound` |
| [restart_all.yml](restart_all.yml) | Stops both services and starts them again in the correct order |
| [backup_pihole.yml](backup_pihole.yml) | Exports the live Pi-hole configuration to a Teleporter archive |

## Pi-hole configuration details

Pi-hole is installed unattended using `/etc/pihole/setupVars.conf` and the official installer from https://install.pi-hole.net.

The repository also ships a systemd override in [roles/configure_pihole/files/pihole-FTL.service.d/99-unbound-dependency.conf](roles/configure_pihole/files/pihole-FTL.service.d/99-unbound-dependency.conf) so `pihole-FTL` waits for Unbound to be available.

The Pi-hole configuration import/export flow uses the Teleporter archive stored in [roles/configure_pihole/files](roles/configure_pihole/files).

## Unbound configuration details

The Unbound role uses the templates under [roles/configure_unbound/templates](roles/configure_unbound/templates) to build:

- the main [roles/configure_unbound/templates/unbound.conf.j2](roles/configure_unbound/templates/unbound.conf.j2) file
- modular fragments for cache tuning, hardening, module configuration, control socket settings, root hints, and no-chroot behavior

The role writes `/etc/unbound/unbound.conf`, downloads `root.hints`, rebuilds `/etc/unbound/unbound.conf.d`, validates the configuration with `unbound-checkconf`, and initializes the remote-control setup.

## Cron jobs

The cron role installs the script [roles/configure_cron/files/optimize_FTL.sh](roles/configure_cron/files/optimize_FTL.sh) and deploys the scheduled tasks from [roles/configure_cron/templates/crontab.j2](roles/configure_cron/templates/crontab.j2).

The current maintenance schedule defined in [roles/configure_cron/vars/main.yml](roles/configure_cron/vars/main.yml) includes:

- daily Pi-hole gravity update at 04:00
- weekly FTL database optimization every Monday at 03:00
- daily Pi-hole update at 02:00, with output redirected to `/var/log/pihole/piholeUpdate.log`


## Log rotation

The optional [configure_log_rotation.yml](configure_log_rotation.yml) playbook installs log rotation and tmpfiles maintenance rules for the host, plus a custom `systemd-journald` configuration.

It deploys:

- a Pi-hole logrotate configuration under `/etc/logrotate.d/pihole`
- tmpfiles rules under `/etc/tmpfiles.d/tmp.conf` to manage `/tmp` and `/var/tmp` retention
- a custom journald configuration under `/etc/systemd/journald.conf.d/00-arm-optimized.conf`

The journald settings are optimized for a low-power ARM device and include:

- volatile storage in RAM
- max runtime log size of `32M`
- per-file limit of `8M`
- compression disabled
- rate limiting for log floods
- disabled audit and forwarding to wall/syslog

This playbook keeps Pi-hole logs, temporary directories, and the journal from growing unbounded on the device.

## Firewall rules

UFW is configured with default deny incoming and default allow outgoing policies. The current allow rules are:

| Rule | Port | Protocol | Source |
|---|---:|---|---|
| SSH | 22 | TCP | `lan_network` |
| DNS | 53 | TCP and UDP | `lan_network` |
| Pi-hole dashboard | 80 | TCP | `lan_network` |
| NTP | 123 | UDP | `lan_network` |

## Project layout

```text
ansible-rpi/
├── ansible.cfg
├── inventory/
│   └── inventory.ini
├── backup_pihole.yml
├── configure_cron.yml
├── configure_log_rotation.yml
├── configure_ntpd.yml
├── configure_pihole.yml
├── configure_ufw.yml
├── configure_unbound.yml
├── install_pihole.yml
├── install_unbound.yml
├── restart_all.yml
├── setup_all.yml
├── start_all.yml
├── stop_all.yml
└── roles/
    ├── common/
    ├── configure_cron/
    ├── configure_log_rotation/
    ├── configure_ntpd/
    ├── configure_pihole/
    ├── configure_ufw/
    ├── configure_unbound/
    ├── get_pihole_backup/
    ├── install_pihole/
    ├── install_unbound/
    └── restart_stack/
```

## Notes

- The default Pi-hole web password is currently `admin`; change it before exposing the dashboard beyond a trusted LAN.
- [configure_pihole.yml](configure_pihole.yml) expects the Teleporter archive to be present under the configured files directory before it runs.
- [setup_all.yml](setup_all.yml) covers the core install/bootstrap path, while [configure_ntpd.yml](configure_ntpd.yml) and [configure_log_rotation.yml](configure_log_rotation.yml) remain separate playbooks for targeted changes.

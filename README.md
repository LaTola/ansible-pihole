# ansible-pihole

![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Armbian](https://img.shields.io/badge/Armbian-DD4814?style=flat&logo=armbian&logoColor=white)
![Orange Pi Zero 3](https://img.shields.io/badge/Orange%20Pi%20Zero%203-FF7900?style=flat&logo=orangepi&logoColor=white)
![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?style=flat&logo=pihole&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-ARM64-lightgrey?style=flat&logo=linux&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-enabled-brightgreen?style=github-actions&logoColor=white)

This repository contains Ansible playbooks for provisioning an Orange Pi Zero 3 running Armbian as a small self-hosted DNS stack. \
The current automation installs and configures:

- Pi-hole as a network-wide DNS sinkhole and dashboard
- Unbound as a local recursive resolver for Pi-hole
- UFW as a host firewall restricted to the local LAN
- chrony or ntp for time synchronization
- root cron jobs for Pi-hole maintenance and periodic updates
- log rotation and tmpfiles handling for Pi-hole logs and temporary directories
- service helpers for start, stop, and restart operations

## Requirements

- Ansible 2.12+ on the controller host
- SSH access to the target device
- A remote user with sudo privileges
- Internet access from the target host during installation
- The following collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

The default inventory and configuration are loaded through [ansible.cfg](ansible.cfg).

## Inventory

The current inventory target is defined in [inventory/inventory.ini](inventory/inventory.ini):

```ini
[pihole]
orangepi ansible_host=192.168.10.3 host_interface=end0
```

## Common usage

Run the main stack setup:

```bash
ansible-playbook setup_all.yml
```

### Individual playbooks

```bash
ansible-playbook install_unbound.yml
ansible-playbook install_pihole.yml
ansible-playbook configure_unbound.yml
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
ansible-playbook restore_pihole.yml
```

The backup playbook exports the current Pi-hole configuration to a Teleporter archive. The restore playbook copies that archive to the target host, imports it into Pi-hole, and refreshes the gravity database.

## Playbook reference

| Playbook | Current behavior |
|---|---|
| [setup_all.yml](setup_all.yml) | Runs the main bootstrap flow for Unbound, Pi-hole, UFW, and log rotation |
| [install_unbound.yml](install_unbound.yml) | Installs Unbound, dnsutils, and the selected NTP package, then applies the Unbound configuration |
| [install_pihole.yml](install_pihole.yml) | Installs Pi-hole unattended, writes setup variables, and enables the service |
| [configure_unbound.yml](configure_unbound.yml) | Applies the Unbound templates, downloads root hints, validates the config, and initializes remote control |
| [configure_ufw.yml](configure_ufw.yml) | Installs UFW and applies LAN-only allow rules for SSH, DNS, dashboard access, and NTP |
| [configure_ntpd.yml](configure_ntpd.yml) | Installs and configures chrony or ntp depending on the selected package |
| [configure_cron.yml](configure_cron.yml) | Installs the maintenance script and replaces the root crontab with the templated schedule |
| [configure_log_rotation.yml](configure_log_rotation.yml) | Deploys logrotate and tmpfiles rules for Pi-hole logs and temporary directories |
| [start_all.yml](start_all.yml) | Starts `unbound` and `pihole-FTL` |
| [stop_all.yml](stop_all.yml) | Stops `pihole-FTL` and `unbound` |
| [restart_all.yml](restart_all.yml) | Stops both services and starts them again in the correct order |
| [backup_pihole.yml](backup_pihole.yml) | Exports the live Pi-hole configuration to a Teleporter archive |
| [restore_pihole.yml](restore_pihole.yml) | Imports a Pi-hole Teleporter archive and refreshes gravity |

## Pi-hole and Unbound details

Pi-hole is installed unattended using `/etc/pihole/setupVars.conf` and the official installer from https://install.pi-hole.net.

The restore role also installs a systemd override for `pihole-FTL.service` so it waits for Unbound to be available before starting. The override template lives in [roles/restore_pihole/templates/99-unbound-dependency.conf.j2](roles/restore_pihole/templates/99-unbound-dependency.conf.j2).

The Unbound role uses the templates under [roles/configure_unbound/templates](roles/configure_unbound/templates) to build the main configuration and modular fragments for cache, hardening, and control settings.

## Log rotation and journald

The optional [configure_log_rotation.yml](configure_log_rotation.yml) playbook installs log rotation and tmpfiles maintenance rules for the host, plus a custom journald configuration. It helps keep Pi-hole logs, temporary directories, and the journal from growing without bound on the device.

## GitHub Actions workflows

This repository includes GitHub Actions workflows that apply individual Ansible playbooks on self-hosted runners when the related files change:

| Workflow file | Trigger | Playbook run |
|---|---|---|
| [.github/workflows/configure-cron.yml](.github/workflows/configure-cron.yml) | push to `main` when `roles/configure_cron/**` changes | `ansible-playbook configure_cron.yml` |
| [.github/workflows/configure-ufw.yml](.github/workflows/configure-ufw.yml) | push to `main` when `roles/configure_ufw/tasks/**` changes | `ansible-playbook configure_ufw.yml` |
| [.github/workflows/configure-ntpd.yml](.github/workflows/configure-ntpd.yml) | push to `main` when `roles/configure_ntpd/**` changes | `ansible-playbook configure_ntpd.yml` |
| [.github/workflows/configure-log-rotation.yml](.github/workflows/configure-log-rotation.yml) | push to `main` when `roles/configure_log_rotation/**` changes | `ansible-playbook configure_log_rotation.yml` |
| [.github/workflows/configure-unbound.yml](.github/workflows/configure-unbound.yml) | push to `main` when `roles/configure_unbound/templates/**` changes | `ansible-playbook configure_unbound.yml` |

## Project layout

```text
ansible-pihole/
├── .github/
│   └── workflows/
├── ansible.cfg
├── inventory/
│   └── inventory.ini
├── backup_pihole.yml
├── configure_cron.yml
├── configure_log_rotation.yml
├── configure_ntpd.yml
├── configure_ufw.yml
├── configure_unbound.yml
├── install_pihole.yml
├── install_unbound.yml
├── restart_all.yml
├── restore_pihole.yml
├── setup_all.yml
├── start_all.yml
├── stop_all.yml
└── roles/
    ├── backup_pihole/
    ├── common/
    ├── configure_cron/
    ├── configure_log_rotation/
    ├── configure_ntpd/
    ├── configure_ufw/
    ├── configure_unbound/
    ├── install_pihole/
    ├── install_unbound/
    ├── restore_pihole/
    └── restart_stack/
```

## Notes

- The default Pi-hole web password is currently `admin`; change it before exposing the dashboard beyond a trusted LAN.
- [restore_pihole.yml](restore_pihole.yml) expects the Teleporter archive to be present under the configured files directory before it runs.
- [setup_all.yml](setup_all.yml) covers the core install/bootstrap path, while [configure_ntpd.yml](configure_ntpd.yml) and [configure_log_rotation.yml](configure_log_rotation.yml) remain separate playbooks for targeted changes.

# ansible-rpi

![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Armbian](https://img.shields.io/badge/Armbian-DD4814?style=flat&logo=armbian&logoColor=white)
![Orange Pi Zero 3](https://img.shields.io/badge/Orange%20Pi%20Zero%203-FF7900?style=flat&logo=orangepi&logoColor=white)
![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?style=flat&logo=pihole&logoColor=white)
![Platform](https://img.shields.io/badge/platform-ARM64-lightgrey?style=flat)

Ansible playbooks for running an Orange Pi Zero 3 with Armbian as a small self-hosted DNS stack with Pi-hole, Unbound, firewall rules, time sync, backups, and scheduled maintenance.

## Stack

```text
Clients
  -> Pi-hole on port 53
      -> Unbound recursive resolver on localhost port 5335
```

| Service | Purpose |
|---|---|
| [Pi-hole](https://pi-hole.net/) | Network-wide DNS filtering and web dashboard |
| [Unbound](https://nlnetlabs.nl/projects/unbound/) | Recursive, validating DNS resolver used by Pi-hole |
| UFW | Host firewall limited to the configured LAN |
| chrony or ntp | Time synchronization, selected with `ntp_package` |
| cron | Root crontab for Pi-hole updates, gravity updates, cleanup, and maintenance |

## Requirements

- Ansible 2.12 or newer on the control machine
- SSH access to the Orange Pi Zero 3
- A remote user with `sudo` privileges
- Internet access from the Orange Pi Zero 3 during install/configuration
- Required Ansible collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

The project uses `inventory/inventory.ini` by default through `ansible.cfg`.

## Inventory

The current target host is:

```ini
[raspberrypi]
rpi ansible_host=192.168.10.3
```

Update `inventory/inventory.ini` before running the playbooks if your Pi uses a different address or LAN.

Important variables:

| Variable | Current value | Notes |
|---|---:|---|
| `lan_network` | `192.168.10.0/24` | Source network allowed through UFW |
| `ntp_package` | `chrony` | Use `chrony` or `ntp` |
| `pihole_default_webpassword` | `admin` | Change this before a real deployment |
| `pihole_teleporter_filename` | `pihole_teleporter.zip` | Pi-hole backup archive used for imports |
| `unbound_config_dir` | `/etc/unbound` | Main Unbound configuration directory |

## Common Commands

Run the full stack setup:

```bash
ansible-playbook setup_all.yml
```

`setup_all.yml` imports these playbooks in order:

1. `install_unbound.yml`
2. `install_pihole.yml`
3. `configure_ufw.yml`

Install or reconfigure individual parts:

```bash
ansible-playbook install_unbound.yml
ansible-playbook install_pihole.yml
ansible-playbook configure_unbound.yml
ansible-playbook configure_pihole.yml
ansible-playbook configure_ufw.yml
ansible-playbook configure_ntpd.yml
ansible-playbook configure_cron.yml
```

Manage the stack services:

```bash
ansible-playbook start_all.yml
ansible-playbook stop_all.yml
ansible-playbook restart_all.yml
```

Back up Pi-hole settings:

```bash
ansible-playbook backup_pihole.yml
```

## Playbook Reference

| Playbook | What it does |
|---|---|
| `setup_all.yml` | Runs Unbound install/configuration, Pi-hole install/configuration, cron setup, and UFW configuration |
| `install_unbound.yml` | Installs Unbound, `dnsutils`, the selected NTP package, then applies Unbound templates |
| `configure_unbound.yml` | Uploads Unbound config, downloads `root.hints`, rebuilds `unbound.conf.d`, runs `unbound-checkconf`, and sets up `unbound-control` |
| `install_pihole.yml` | Installs Pi-hole unattended, then imports Pi-hole configuration and installs cron maintenance |
| `configure_pihole.yml` | Copies `/etc/hosts`, installs the `pihole-FTL` systemd override, imports the Teleporter archive, and runs `pihole -g` |
| `configure_ufw.yml` | Installs/enables UFW and applies LAN-only rules |
| `configure_ntpd.yml` | Installs and configures `chrony` or `ntp` based on `ntp_package` |
| `configure_cron.yml` | Installs root maintenance scripts and root crontab |
| `start_all.yml` | Starts Unbound, then `pihole-FTL` |
| `stop_all.yml` | Stops `pihole-FTL`, then Unbound |
| `restart_all.yml` | Stops `pihole-FTL` and Unbound, then starts Unbound and `pihole-FTL` |
| `backup_pihole.yml` | Exports a Pi-hole Teleporter archive and saves it under `roles/configure_pihole/files/` |

## Pi-hole Configuration

Pi-hole is installed unattended using `/etc/pihole/setupVars.conf` and the official installer from `https://install.pi-hole.net`.

After installation, this project manages Pi-hole settings with the bundled Teleporter archive:

```text
roles/configure_pihole/files/pihole_teleporter.zip
```

To capture the current live Pi-hole configuration:

```bash
ansible-playbook backup_pihole.yml
```

To re-import the saved Teleporter archive:

```bash
ansible-playbook configure_pihole.yml
```

The Pi-hole systemd override in `roles/configure_pihole/files/pihole-FTL.service.d/` makes `pihole-FTL` depend on Unbound.

## Unbound Configuration

Unbound templates live in:

```text
roles/configure_unbound/templates/
```

The role writes `/etc/unbound/unbound.conf`, rebuilds `/etc/unbound/unbound.conf.d`, downloads root hints from Internic, validates the result with `unbound-checkconf`, and runs `unbound-control-setup`.

The template set includes cache tuning, hardening, module configuration, control socket configuration, root hints, and no-chroot settings.

## Cron Jobs

`configure_cron.yml` installs `/root/.local/bin/optimize_FTL.sh` and replaces root's crontab from `roles/configure_cron/templates/crontab.j2`.

Configured maintenance jobs include:

- Restart Unbound after boot delay
- Sync filesystem every 5 minutes
- Update Pi-hole gravity daily
- Optimize the FTL database weekly
- Update Pi-hole daily
- Clean old `/tmp` files weekly
- Clean old `/var/log` files weekly

## Firewall Rules

UFW is configured with default deny incoming and default allow outgoing.

| Rule | Port | Protocol | Source |
|---|---:|---|---|
| SSH | 22 | TCP | `lan_network` |
| DNS | 53 | TCP and UDP | `lan_network` |
| Pi-hole dashboard | 80 | TCP | `lan_network` |
| NTP | 123 | UDP | `lan_network` |

## Project Layout

```text
ansible-rpi/
├── ansible.cfg
├── inventory/
│   └── inventory.ini
├── setup_all.yml
├── install_unbound.yml
├── install_pihole.yml
├── configure_unbound.yml
├── configure_pihole.yml
├── configure_ufw.yml
├── configure_ntpd.yml
├── configure_cron.yml
├── start_all.yml
├── stop_all.yml
├── restart_all.yml
├── backup_pihole.yml
└── roles/
    ├── common/
    ├── install_unbound/
    ├── configure_unbound/
    ├── install_pihole/
    ├── configure_pihole/
    ├── configure_ufw/
    ├── configure_ntpd/
    ├── configure_cron/
    ├── restart_stack/
    └── get_pihole_backup/
```

## Notes

- `configure_pihole.yml` assumes `roles/configure_pihole/files/pihole_teleporter.zip` exists.
- `install_pihole.yml` already runs `configure_pihole` and `configure_cron`.
- `install_unbound.yml` already runs `configure_unbound`.
- The default Pi-hole web password in inventory is currently `admin`; change it before exposing the dashboard beyond a trusted LAN.

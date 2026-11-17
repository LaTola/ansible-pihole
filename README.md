# ansible-pihole

![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Armbian](https://img.shields.io/badge/Armbian-DD4814?style=flat&logo=armbian&logoColor=white)
![Orange Pi Zero 3](https://img.shields.io/badge/Orange%20Pi%20Zero%203-FF7900?style=flat&logo=orangepi&logoColor=white)
![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?style=flat&logo=pihole&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-ARM64-lightgrey?style=flat&logo=linux&logoColor=white)

Ansible automation for an Orange Pi Zero 3 running Armbian as a small DNS and time-service appliance. It provisions:

- Pi-hole for network-wide DNS filtering and its web interface
- Unbound as a local recursive resolver on `127.0.0.1:5335`
- UFW with LAN-only access to SSH, DNS, HTTP, and NTP
- chrony or ntp, optionally serving time to the LAN
- root cron jobs for Pi-hole updates and database maintenance
- logrotate, systemd-tmpfiles, and journald limits for a low-resource device
- Pi-hole Teleporter backup and restore
- helper playbooks to start, stop, or restart the DNS stack

The defaults are specific to the host and `192.168.10.0/24` network in this repository. Review the inventory and group variables before running anything.

## Requirements

### Controller

- Ansible 2.12 or newer
- SSH access to the target
- The `community.general`, `ansible.posix`, and `ansible.utils` collections

Install the required collections with:

```bash
ansible-galaxy collection install community.general ansible.posix ansible.utils
```

`ansible.cfg` automatically selects `inventory/inventory.ini`, enables the `ansible.posix.profile_tasks` callback, and uses SSH pipelining.

### Target

- A Debian/Armbian-style system using APT and systemd
- A remote account that can become root with sudo
- Internet access for APT, the Pi-hole installer, Unbound root hints, and gravity updates
- A static IPv4 address is strongly recommended

## Configure the target

The checked-in inventory currently contains:

```ini
[pihole]
orangepi ansible_host=192.168.10.3 host_interface=end0
```

Edit [inventory/inventory.ini](inventory/inventory.ini) for the target address and interface. If needed, set the SSH user in the inventory (`ansible_user=...`) or pass it with `-u`.

Review these group-variable files as well:

| File | Important settings |
|---|---|
| [lan.yml](inventory/group_vars/pihole/lan.yml) | `lan.network`, used by UFW, Unbound, and the NTP configuration |
| [ntp.yml](inventory/group_vars/pihole/ntp.yml) | `ntp.package` (`chrony` or `ntp`) and `ntp.pool` |
| [pihole_app.yml](inventory/group_vars/pihole/pihole_app.yml) | Pi-hole paths, packages, Teleporter locations, and the transient bootstrap web password |
| [unbound.yml](inventory/group_vars/pihole/unbound.yml) | Unbound paths, account, and packages |
| [journalctl.yml](inventory/group_vars/pihole/journalctl.yml) | journald storage, size, and rate limits |
| [systemd.yml](inventory/group_vars/pihole/systemd.yml) | systemd paths and temporary-file retention |

Test connectivity before provisioning:

```bash
ansible pihole -m ping
```

## Usage

Provision the complete stack:

```bash
ansible-playbook setup_all.yml
```

The aggregate playbook runs Unbound installation/configuration, Pi-hole installation, Teleporter restore, cron configuration, UFW, NTP, and log maintenance. Some work is repeated by the current composition: `install_pihole.yml` already includes restore and cron roles, after which `setup_all.yml` imports the standalone restore and cron playbooks again.

Run a single area when making a targeted change:

```bash
ansible-playbook install_unbound.yml
ansible-playbook install_pihole.yml
ansible-playbook configure_unbound.yml
ansible-playbook configure_ufw.yml
ansible-playbook configure_ntpd.yml
ansible-playbook configure_cron.yml
ansible-playbook configure_log_rotation.yml
```

Control the DNS services:

```bash
ansible-playbook start_all.yml
ansible-playbook stop_all.yml
ansible-playbook restart_all.yml
```

The start order is Unbound then `pihole-FTL`; stop and restart operations shut down `pihole-FTL` before Unbound.

## Playbook reference

| Playbook | Behavior |
|---|---|
| [setup_all.yml](setup_all.yml) | Runs the complete sequence described above |
| [install_unbound.yml](install_unbound.yml) | Installs Unbound, DNS utilities, and the selected NTP package, then fully configures Unbound |
| [install_pihole.yml](install_pihole.yml) | Installs Pi-hole when `pihole-meta` is absent, then runs restore and cron configuration |
| [configure_unbound.yml](configure_unbound.yml) | Rebuilds `unbound.conf.d`, downloads root hints, validates the configuration, initializes control certificates, and restarts the DNS services when changed |
| [configure_ufw.yml](configure_ufw.yml) | Sets deny-incoming/allow-outgoing defaults and enables LAN rules for TCP 22, TCP/UDP 53, TCP 80, and UDP 123 |
| [configure_ntpd.yml](configure_ntpd.yml) | Installs and configures the selected `chrony` or `ntp` service |
| [configure_cron.yml](configure_cron.yml) | Installs the FTL optimization script and replaces root's complete crontab |
| [configure_log_rotation.yml](configure_log_rotation.yml) | Installs Pi-hole logrotate, tmpfiles cleanup, and journald resource-limit configuration, then restarts journald |
| [backup_pihole.yml](backup_pihole.yml) | Generates a Teleporter archive on the target, fetches it into the role's files directory, and removes the target-side temporary archive |
| [restore_pihole.yml](restore_pihole.yml) | If the local archive exists, replaces `/etc/hosts`, installs the Unbound systemd dependency, imports the archive, and rebuilds gravity |
| [start_all.yml](start_all.yml) | Starts and enables Unbound and `pihole-FTL` when their service units exist |
| [stop_all.yml](stop_all.yml) | Stops both services when their service units exist; the common role still defaults them to enabled |
| [restart_all.yml](restart_all.yml) | Stops and starts the two services in dependency order |

## Backup and restore

The archive path is configured by `pihole.teleporter` in [pihole_app.yml](inventory/group_vars/pihole/pihole_app.yml). With the current defaults, both playbooks use:

```text
roles/restore_pihole/files/pihole_teleporter.zip
```

Create or replace that controller-side archive from the live target:

```bash
ansible-playbook backup_pihole.yml
```

Restore it to the target:

```bash
ansible-playbook restore_pihole.yml
```

The restore role silently skips its restore block when the archive is absent. When present, it can replace Pi-hole settings, databases, `/etc/hosts`, and other state contained in the archive. Teleporter archives may contain configuration, query history, leases, and other network-sensitive data; protect them appropriately and review changes before committing a newly generated archive.

## Scheduled maintenance

`configure_cron.yml` replaces the entire root crontab with the repository template. The current schedule is:

| Time | Job |
|---|---|
| Daily 01:00 | Delete `.backup` logs older than seven days under `/var/log` |
| Monday 01:30 | Delete `.backup` files older than seven days under `/var/log.hdd` |
| Daily 02:00 | Update Pi-hole |
| Monday 03:00 | Stop FTL, integrity-check/VACUUM/optimize its SQLite databases, and restart FTL |
| Daily 04:00 | Update gravity |

Times use the target host's timezone.

## Implementation notes

- Pi-hole is installed from `https://install.pi-hole.net`. The unattended seed uses the inventory address with a `/24` prefix and initially uses Cloudflare DNS; a Teleporter restore can overwrite those settings.
- `pihole.default_webpassword`, currently `admin`, is a transient bootstrap setting used only for a fresh installation. The Teleporter restore overwrites it with the password from the archive.
- Unbound listens only on loopback at port 5335. Its templates are tuned for a 1 GB ARM board and recreate `/etc/unbound/unbound.conf.d` on every configuration run.
- The default journald configuration is volatile, limited to 32 MB, and uncompressed. The tmpfiles policy clears `/tmp` and `/var/tmp` entries after seven days.
- UFW is enabled while rules are applied. Ensure `lan.network` includes the controller before running the firewall playbook or SSH access can be lost.

## GitHub Actions

Five workflows run targeted playbooks on a self-hosted runner after matching pushes to `main`:

| Workflow | Watched paths | Playbook |
|---|---|---|
| [configure-cron.yml](.github/workflows/configure-cron.yml) | `roles/configure_cron/**`, `configure_cron.yml` | `configure_cron.yml` |
| [configure-log-rotation.yml](.github/workflows/configure-log-rotation.yml) | role files, `journalctl.yml`, playbook | `configure_log_rotation.yml` |
| [configure-ntpd.yml](.github/workflows/configure-ntpd.yml) | role files, `ntp.yml`, playbook | `configure_ntpd.yml` |
| [configure-ufw.yml](.github/workflows/configure-ufw.yml) | role task files, playbook | `configure_ufw.yml` |
| [configure-unbound.yml](.github/workflows/configure-unbound.yml) | role templates, `unbound.yml`, playbook | `configure_unbound.yml` |

The runner must have Ansible, the required collections, SSH credentials, and network access to the target. Each workflow removes the checked-out workspace contents after its run.

## Project layout

```text
.
├── .github/workflows/       # Targeted self-hosted deployments
├── inventory/
│   ├── inventory.ini       # Target host
│   └── group_vars/          # Stack and host settings
├── roles/                   # Installation, configuration, backup, and service roles
├── ansible.cfg
├── setup_all.yml            # Complete provisioning sequence
├── install_*.yml            # Installation entry points
├── configure_*.yml          # Targeted configuration entry points
├── backup_pihole.yml
├── restore_pihole.yml
├── start_all.yml
├── stop_all.yml
└── restart_all.yml
```

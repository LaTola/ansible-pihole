# ansible-rpi

![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-A22846?style=flat&logo=raspberrypi&logoColor=white)
![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?style=flat&logo=pihole&logoColor=white)
![Platform](https://img.shields.io/badge/platform-ARMv6%2FARMv7-lightgrey?style=flat)

Ansible playbooks to automate the setup and configuration of a Raspberry Pi as a self-hosted, privacy-focused DNS stack with ad-blocking and persistent DNS caching.

## Stack

```
Pi-hole (ad-blocking DNS)
    └──> Unbound (recursive DNS resolver, port 5335)
```

| Service | Role |
|---|---|
| [Pi-hole](https://pi-hole.net/) | Network-wide ad blocker and DNS server (installed via automated installer) |
| [Unbound](https://nlnetlabs.nl/projects/unbound/) | Recursive, validating DNS resolver upstream for Pi-hole |

## Requirements

- Ansible 2.12+
- `community.general` collection (for UFW module)
- `ansible.posix` collection (for profiling callbacks)
- A Raspberry Pi reachable at `192.168.10.2` with SSH access and `sudo` privileges

Install required collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

## Inventory

The target host is defined in `inventory/inventory.ini`. Update `ansible_host` to match your Raspberry Pi's IP address.

```ini
[raspberrypi]
rpi ansible_host=192.168.10.2
```

## Playbooks

### Installation

```bash
# Install Unbound
ansible-playbook install_unbound.yml

# Install Pi-hole and apply configuration in one step
ansible-playbook install_pihole.yml
```

### Configuration

```bash
# Configure Unbound
ansible-playbook config_unbound.yml

# Configure Pi-hole (imports settings via teleporter backup)
ansible-playbook config_pihole.yml

# Configure UFW firewall
ansible-playbook setup_ufw.yml
```

> **Note:** `install_pihole.yml` runs both the `install_pihole` and `configure_pihole` roles in sequence, so a separate `config_pihole.yml` run is not needed after a fresh install.

### Stack lifecycle

```bash
ansible-playbook start_all.yml    # Start: Unbound → Pi-hole
ansible-playbook stop_all.yml     # Stop:  Pi-hole → Unbound
ansible-playbook restart_all.yml  # Full ordered restart of the stack
```

### Backup

```bash
# Export Pi-hole settings and save locally as pihole_teleporter.zip
ansible-playbook backup_pihole.yml
```

## Firewall Rules (UFW)

| Rule | Port | Protocol | Source |
|---|---|---|---|
| Allow SSH | 22 | TCP | LAN (`192.168.10.0/24`) |
| Allow DNS | 53 | TCP+UDP | LAN |
| Allow Pi-hole dashboard | 80 | TCP | LAN |
| Allow loopback in/out | — | — | `lo` interface |
| Default deny incoming | — | — | — |
| Default allow outgoing | — | — | — |

## Project Structure

```
ansible-rpi/
├── inventory/
│   └── inventory.ini          # Host and variable definitions
├── roles/
│   ├── common/                # Shared tasks (service management, UFW) and handlers
│   ├── install_unbound/       # Install Unbound via apt
│   ├── install_pihole/        # Install Pi-hole via automated installer
│   ├── configure_unbound/     # Unbound config templates
│   ├── configure_pihole/      # Pi-hole teleporter import + systemd overrides
│   ├── setup_ufw/             # UFW firewall rules
│   ├── restart_stack/         # Ordered stack restart
│   └── get_pihole_backup/     # Export and fetch Pi-hole teleporter backup
├── ansible.cfg
├── install_unbound.yml
├── install_pihole.yml
├── config_unbound.yml
├── config_pihole.yml
├── setup_ufw.yml
├── start_all.yml
├── stop_all.yml
├── restart_all.yml
└── backup_pihole.yml
```

## Pi-hole Configuration

### Fresh install

Pi-hole is installed unattended using the official installer script. The web dashboard password is set via the `pihole_default_webpassword` variable in `inventory/inventory.ini`.

```ini
pihole_default_webpassword="your-password"
```

Running `install_pihole.yml` handles both installation and initial configuration import in one step.

### Updating settings

Pi-hole settings are managed via the [Teleporter](https://docs.pi-hole.net/core/pihole-command/#teleporter) backup/restore mechanism:

1. Run `ansible-playbook backup_pihole.yml` to export the current settings.
2. Modify the exported `roles/configure_pihole/files/pihole_teleporter.zip` as needed.
3. Run `ansible-playbook config_pihole.yml` to re-import.

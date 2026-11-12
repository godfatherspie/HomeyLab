# Phase 1: Router/Firewall VM

## Goal
Build a Debian VM that sits between three isolated virtual subnets and acts as the lab's router. Firewall rules, DHCP and DNS come in later phases.

## Environment
- Host: Fedora laptop (i5-1135G7, 16GB RAM), KVM/QEMU + libvirt + virt-manager
- Guest: Debian 13.7.0 (netinst, minimal), 1 vCPU, 1GB RAM, 8GB qcow2 disk

## Network design

| Network | Subnet | Router address | Purpose |
|---|---|---|---|
| default (libvirt NAT) | 192.168.122.0/24 | DHCP | WAN / internet |
| lab-users | 10.10.10.0/24 | 10.10.10.1 | client machines |
| lab-servers | 10.10.20.0/24 | 10.10.20.1 | web/SSH servers |
| lab-mgmt | 10.10.30.0/24 | 10.10.30.1 | monitoring/management |

The three lab networks are isolated libvirt bridges with no DHCP and no host IP. They act like unplugged switches, and only the router VM connects them.

## Steps

### 1. Virtualization on the host
- Installed the virtualization group and enabled libvirt:
  `sudo dnf install @virtualization`, `sudo systemctl enable --now libvirtd`
- Added my user to the `libvirt` group
- Set `LIBVIRT_DEFAULT_URI=qemu:///system` in `~/.bashrc` so `virsh` and virt-manager see the same VMs and networks
- Enabled the `default` NAT network and set it to autostart

### 2. Isolated lab networks
Defined `lab-users`, `lab-servers` and `lab-mgmt` as bridge-only libvirt networks (XML in `networks/`), all set to autostart.

### 3. Router VM
- Moved the Debian ISO to `/var/lib/libvirt/images/` (SELinux blocks libvirt from reading `~/Downloads`)
- Created the VM with `virt-install` (see `scripts/create-router-vm.sh`) with **four virtio NICs in this order**: default, lab-users, lab-servers, lab-mgmt
- Debian install choices: hostname `lab-router`, guided partitioning (entire virtual disk), only SSH server and standard system utilities selected (no desktop), GRUB on `/dev/vda`, root password left blank so the user gets sudo

### 4. Verifying interface mapping
Matched MAC addresses between `virsh domiflist lab-router` (host) and `ip -br link` (guest) rather than trusting NIC order:

| Interface | Network |
|---|---|
| enp1s0 | default (WAN) |
| enp2s0 | lab-users |
| enp3s0 | lab-servers |
| enp4s0 | lab-mgmt |

### 5. Static addressing
Added the three lab interfaces to `/etc/network/interfaces` with static IPs (`.1/24` in each subnet) and brought them up with `ifup`.
Config saved in `configs/router/interfaces`.

### 6. IP forwarding
```
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl --system
```
Linux drops packets that arrive on one interface and need to leave on another by default. Setting this to 1 lets the VM forward between subnets. The file in `/etc/sysctl.d/` makes it persist across reboots.

## Verification
- `ip -4 -br a` shows all three lab addresses
- `sysctl net.ipv4.ip_forward` returns 1
- `ping debian.org` works from the router (WAN OK)

## Troubleshooting log

| Problem | Cause | Fix |
|---|---|---|
| `git push` failed with "Password authentication is not supported" | Remote used HTTPS, and GitHub no longer accepts passwords | Generated a new ed25519 key, added it to GitHub, switched remote with `git remote set-url origin git@github.com:...` |
| Forgotten passphrase on old SSH key | Passphrases can't be recovered | Made a new key under a separate filename and configured `~/.ssh/config` with `IdentitiesOnly yes` |
| `su -` failed with "authentication failure" | Blank root password during install disables the root account | Used `sudo` with my own user's password instead |
| `osinfo-query ... \| tail -3` hid Debian 13 | Output sorted alphabetically, newer versions weren't last | Used `grep -E 'debian1[0-9]'` instead |

## Next
- Install and configure dnsmasq for DHCP and DNS on each subnet
- Create a client VM on lab-users and a server VM on lab-servers
- Write nftables rules (default deny between subnets, NAT for internet access)

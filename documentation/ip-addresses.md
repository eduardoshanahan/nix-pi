# IP addresses

This repo configures the Pis for DHCP (`networking.useDHCP = true`), so static IPs are assigned via DHCP reservations on the router (or via Pi-hole DHCP if you switch to it).

## Keep private

Do not commit your real home/LAN IP mapping to a public repo.

Instead:

- Copy this file to `documentation/ip-addresses.local.md`
- Fill in the real mapping there
- Keep it untracked (it is ignored by `.gitignore`)

## Template (fill in locally)

- `rpi-box-01`: `<ip>`
- `rpi-box-02`: `<ip>`
- `rpi-box-03`: `<ip>`

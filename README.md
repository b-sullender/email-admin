# email-admin

**email-admin** is a collection of scripts to configure and manage a file-based email server on Debian. Currently works for Debian 12 (Bookworm), updates are needed to work with Debian 13 (Trixie) or newer.

Recommended Prerequisites:
1. Get ISP static IP address.
2. Confirm ports 587, 465 (out bound), and 25 (in bound) are not blocked by ISP.
3. Confirm a rDNS pointer exists or can be created.

## Features
- Install and set up a complete email server
- Configure **OpenDKIM**, **Postfix**, and **Dovecot**
- Easily add or delete domains & email accounts

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/b-sullender/email-admin.git && cd email-admin
sudo bash install
cd ../ && rm -rf email-admin
```

## Usage

After installation, configure the services:

```bash
sudo configure-opendkim
sudo configure-postfix
sudo configure-dovecot
```

### Managing Domains

Add a new domain:

```bash
sudo add-email-domain
```

Delete a domain:

```bash
sudo delete-email-domain
```

### Managing Email Accounts

Add a new email account:

```bash
sudo add-email-account
```

Delete an email account:

```bash
sudo delete-email-account
```

## License

[MIT](LICENSE)

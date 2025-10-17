# email-admin

**email-admin** is a collection of scripts to configure and manage a file-based email server on Debian.

## Features
- Install and set up a complete email server
- Configure **Dovecot**, **OpenDKIM** and **Postfix**
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
sudo configure-dovecot
sudo configure-opendkim
sudo configure-postfix
```

### Managing Domains

```bash
sudo add-email-domain
```

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

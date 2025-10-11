# email-admin

**email-admin** is a collection of scripts to configure and manage a file-based email server on Debian.

## Features
- Install and set up a complete email server
- Configure **Postfix**, **Dovecot**, and **OpenDKIM**
- Easily add or delete email accounts

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/b-sullender/email-admin.git && cd email-admin
sudo bash install
cd ../ && rm -rf email-admin
````

## Usage

After installation, configure the services:

```bash
sudo configure-opendkim
sudo configure-postfix
sudo configure-dovecot
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

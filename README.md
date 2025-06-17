# LDAP Password Expiration Notifier

[![ShellCheck](https://img.shields.io/badge/shellcheck-passed-brightgreen)](https://www.shellcheck.net/)
[![License: Beerware](https://img.shields.io/badge/license-Beerware-orange?style=flat-square)](https://en.wikipedia.org/wiki/Beerware)
[![Bash Compatible](https://img.shields.io/badge/bash-compatible-blue.svg)](https://www.gnu.org/software/bash/)

This Bash script queries an LDAP directory to find users whose passwords are nearing expiration, sends them notification emails, and generates a daily report for administrators.

## Features

* Lightweight and pure Bash implementation
* Connects to LDAP server (`ldap://`, `ldaps://`, StartTLS support)
* Calculates password expiration based on LDAP password policies
* Sends email notifications via `msmtp`
* Sends daily reports to administrators
* Fully configurable: LDAP, SMTP, portal URL, company branding

## Prerequisites

You can install required packages on Rocky Linux / RHEL (EPEL repository required for msmtp):

```bash
sudo dnf install epel-release
sudo dnf install openldap-clients msmtp
```

Or on openSUSE Leap 15.6:

```bash
sudo zypper addrepo https://download.opensuse.org/repositories/server:mail/openSUSE_Leap_15.6/server:mail.repo
sudo zypper refresh
sudo zypper install openldap2-client msmtp
```

Or on openSUSE Tumbleweed:

```bash
sudo zypper addrepo https://download.opensuse.org/repositories/server:mail/openSUSE_Tumbleweed/server:mail.repo
sudo zypper refresh
sudo zypper install openldap2-client msmtp
```

## Configuration

Edit the following variables inside the script:

| Variable                                             | Description                                           |
| :--------------------------------------------------- | :---------------------------------------------------- |
| `ldap_uri`                                           | LDAP server URI                                       |
| `ldap_bind_dn`                                       | LDAP Bind DN                                          |
| `ldap_bind_pw`                                       | Password for bind DN                                  |
| `use_starttls`                                       | Use StartTLS on `ldap://` connections                 |
| `use_tls_verify`                                     | Verify TLS certificates                               |
| `tls_cacert_path`                                    | Path to CA certificates                               |
| `default_max_age`                                    | Default password lifetime (seconds)                   |
| `default_expire_warning`                             | Default warning threshold before expiration (seconds) |
| `search_base`, `search_filter`                       | LDAP search parameters                                |
| `smtp_server`, `smtp_port`, `smtp_user`, `smtp_pass` | SMTP settings                                         |
| `mail_sender`, `report_recipient`                    | Email addresses                                       |
| `company_name`, `company_team`, `company_portal_url` | Company branding                                      |

> **Tip:**
> If you use [ldappass-ui](https://github.com/fallboyz/ldappass-ui) for password resets, set the `company_portal_url` variable to match its deployed URL.

## How It Works

1. Search LDAP for all user accounts.
2. For each user:

   * Fetch `pwdChangedTime`
   * Calculate expiration time
   * If the password is expiring soon or already expired:

     * Send notification email
3. Send a daily summary report to the administrator.

## Example Usage

Manual run:

```bash
bash ldap_password_notify.sh
```

Scheduled daily run (via crontab):

```bash
0 8 * * * /bin/bash /path/to/ldap_password_notify.sh
```

## Notes

* If no user-specific policy is found (`pwdPolicySubentry`), the script uses the global policy or defaults.
* TLS/SSL configurations ensure compatibility with secure LDAP environments.
* Tested on OpenLDAP servers with password policy overlay enabled.

## Email Examples

### User Notification Email

```
Subject: [ExampleCorp] LDAP Password is Expiring Soon

Hi John Doe,

Your LDAP password will expire in 5 days (on 2024-05-03).

Update your password here: https://portal.example.com

For assistance, contact admin@example.com.

- ExampleCorp IT Team
```

### Admin Report Email

```
Subject: [ExampleCorp] LDAP Password Expiration Report

LDAP Password Expiration Report

Total Users Checked: 394
Expired Accounts: 1
Warnings Sent: 1

Details:
Expired: user1
Warning sent: user1 (user1@example.com)
Warning sent: user2 (user2@example.com) - expires in 4 days (on 2025-06-21 00:00:00)
No password change date: user3
...
```

## License

```
"The Beer-Ware License" (Revision 42):
<fallboyz@umount.net> wrote this file. As long as you retain this notice, you
can do whatever you want with this stuff. If we meet someday, and you think
this stuff is worth it, you can buy me a beer in return.
```

## Contributions

Pull requests are welcome!
If you find a bug or have ideas for improvements, feel free to open an issue.

## Acknowledgements

* [ldappass-ui](https://github.com/fallboyz/ldappass-ui) for secure password management portal
* [ShellCheck](https://www.shellcheck.net/) for static analysis of shell scripts

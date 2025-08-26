
<h1 align="center">guacamole-docker 🥑</h1>
<p align="center">
  <img alt="Ubuntu" src="https://img.shields.io/badge/OS-Ubuntu%2024.04-E95420?logo=ubuntu&logoColor=white">
  <img alt="Docker Compose" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white">
  <img alt="Apache Guacamole" src="https://img.shields.io/badge/Guacamole-1.6.x-00a86b">
  <img alt="Bash" src="https://img.shields.io/badge/Scripts-Bash-4EAA25?logo=gnubash&logoColor=white">
  <a href="https://github.com/lhlaib/guacamole-docker"><img alt="GitHub Stars" src="https://img.shields.io/github/stars/lhlaib/guacamole-docker?style=social"></a>
  <a href="https://github.com/lhlaib"><img alt="GitHub Follow" src="https://img.shields.io/github/followers/lhlaib?label=Follow&style=social"></a>
</p>

<p align="center">
  A fast Docker setup for <b>Apache Guacamole</b> on <b>Ubuntu 24.04</b> — RDP / VNC / SSH, session recording, LDAP, IP banning, time/IP restrictions, and a ready-to-brand login page.
</p>

中文版說明請見： [README.zh-tw.md](../docs/zh-tw/README.md)

---

## Why this repo?

- **Zero to Guacamole in minutes** – scripts handle Docker install, DB init, permissions, and service start.
- **Opinionated defaults** – recording enabled out of the box; security toggles are one env var away.
- **Brand-ready** – a sample branding extension plus a one-click pack script.
- **Operational tooling** – scripts for restart, status, and logs so you can troubleshoot quickly.

> If this saves you time, please ⭐ the repo. It helps others discover it.

---

## Requirements

- **Ubuntu 24.04 LTS**
- `sudo` privileges
- Internet access to pull Docker images
- Port **80/tcp** available on the host (customizable in `docker-compose.yml`)

---

## Quick start

> Run everything from the repository root.

1) Make scripts executable  
```bash
chmod +rx *.sh
```

2.  Install Docker & Compose

```bash
./00_install_docker.sh
```

3.  Bootstrap everything (DB schema, recording dir permissions, containers)

```bash
./01_manager.sh init-all
```
4.  Restart services when configs change

```bash
./02_restart.sh
```

5.  Check container health

```bash
./03_check.sh
```

7.  Tail/export logs

```bash
./04_log.sh
```


Open the UI: `http://<your-host>`.

> ⚠️ **Default admin**: `guacadmin / guacadmin`  
> Immediately sign in, **change the password**, create a second admin, verify it works, and **disable `guacadmin`**.

* * *

Where do recordings go?
-----------------------

*   Raw protocol recordings are persisted under **`./recordings/`** on the host (mounted to `/var/lib/guacamole/recordings`).
*   The web UI includes a **built-in player** for playback.
*   Convert to `.m4v/.mp4` only when you need to share/archive (saves disk in day-to-day ops).

* * *

Scripts you’ll use most
-----------------------

| Script | What it does |
| --- | --- |
| `00_install_docker.sh` | Installs Docker & Compose |
| `01_manager.sh` | Manager with subcommands (`init-all`, `status`, `logs`, `exec`, …) |
| `02_restart.sh` | Restarts the stack |
| `03_check.sh` | Prints `docker compose ps` and health |
| `04_log.sh` | Follows and saves logs under `./log/` |

* * *

Configuration
-------------

### `docker-compose.yml` – feature toggles

Enable features by switching values to `"true"` (restart after changes):

```yaml
# --- Web add-ons ---
RECORDING_ENABLED: "true"   # 🎥 Session recording & playback
LDAP_ENABLED:      "true"   # 🔐 LDAP auth (configure guacamole.properties)
TOTP_ENABLED:      "false"  # 🔑 2FA (TOTP)
BAN_ENABLED:       "true"   # 🚫 IP ban on repeated failures
RESTRICT_ENABLED:  "true"   # 🕘 Source/time access restrictions
JSON_ENABLED:      "false"  # 🔗 JSON auth (custom portal/SSO)
```

**Recommended starting points**

*   Just to get going: keep `RECORDING_ENABLED` and `BAN_ENABLED` on.
*   Corporate/School login: turn on `LDAP_ENABLED` and configure properties.
*   Stricter environments: enable `TOTP_ENABLED` and `RESTRICT_ENABLED`.

> Apply changes with `./02_restart.sh`.

* * *

### `guacamole.properties` – server behavior, LDAP, recording, session

File lives at repo root (`./guacamole.properties`) and is mounted to `/etc/guacamole/guacamole.properties`.

```properties
# ===== LDAP (adjust to your tree) =====
ldap-hostname: ldap.school.edu.tw
ldap-user-base-dn: dc=school,dc=edu,dc=tw
ldap-group-base-dn: cn=groups,dc=school,dc=edu,dc=tw
ldap-search-bind-dn: uid=root,cn=users,dc=school,dc=edu,dc=tw
ldap-search-bind-password: your_password
ldap-group-name-attribute: cn
ldap-member-attribute: memberUid
ldap-member-attribute-type: uid

# ===== Recording (must match compose mount) =====
recording-search-path=/var/lib/guacamole/recordings

# ===== Languages =====
allowed-languages: en

# ===== API session idle timeout (minutes) =====
api-session-timeout: 120

# ===== Ban (when BAN_ENABLED is true) =====
#ban-max-invalid-attempts: 5
#ban-address-duration: 300

# ===== Debug logging =====
#log-level: trace
```

**Notes**

*   **LDAP**: DNs must match your directory structure. If unsure, verify with `ldapsearch`.
*   **Recording path** must align with the volume mount (`/var/lib/guacamole/recordings` here).
*   **Session timeout**: 60–120 minutes is common; too short frustrates users.
*   **Ban**: a sane baseline is _5 failed attempts → 5 minutes ban_.

* * *

First RDP connection (example)
------------------------------

1.  Sign in as admin → **Settings → Connections → New Connection**
2.  Choose **RDP** and fill in:
    *   **Hostname**: `10.0.0.10` or `server.school.edu.tw`
    *   **Username/Password**: can use `${GUAC_USERNAME}` / `${GUAC_PASSWORD}` to reuse portal login
    *   **Ignore certificate errors**: enable if your RDP server uses self-signed certs
    *   **Display**: fixed resolution or “resize to client”
    *   **Recording**: enable; path template `${HISTORY_PATH}/${HISTORY_UUID}` is clean and unique
3.  Save → return to Home → click the card to connect

* * *

Branding the login page
-----------------------

Location: **`extensions/guacamole-branding-example/`**

**What you can change**

*   Text/labels: `translations/en.json`
*   Login HTML: `html/warning.html`
*   Image (keep the filename): `resources/images/saturn/saturn.png`

**Pack & apply**

```bash
cd extensions/guacamole-branding-example
chmod +x 01_pack_branding.sh         # first time
./01_pack_branding.sh                # builds ../guacamole-branding-example.jar

cd ../../
./02_restart.sh                      # reload web
# Force-refresh your browser (Ctrl+F5 / Cmd+Shift+R)
```

More details: `extensions/guacamole-branding-example/README.md`

* * *

Project layout
--------------

```
├── 00_install_docker.sh
├── 01_manager.sh
├── 02_restart.sh
├── 03_check.sh
├── 04_log.sh
├── docker-compose.yml
├── guacamole.properties
├── recordings/                    # Session recordings (persisted)
├── log/                           # Log files
└── extensions/
    └── guacamole-branding-example/
        ├── 01_pack_branding.sh
        ├── README.md
        ├── guac-manifest.json
        ├── html/warning.html
        ├── translations/en.json
        └── resources/images/saturn/saturn.png
```

* * *

FAQ
---

*   **UI doesn’t load**  
    Port 80 may be taken. Change the mapping in compose from `80:8080` to `8080:8080` and use `http://<host>:8080`.
*   **LDAP login fails**  
    Verify bind DN/password and base DNs with `ldapsearch`. Check the `guacamole` container logs via `./04_log.sh`.
*   **No recordings**  
    Confirm permissions on `recordings/` (the `init-all` step sets them) and that recording is enabled on the connection.
*   **Logo doesn’t change**  
    Re-pack the branding JAR, restart the stack, then hard-refresh the browser.
*   **LDAP tooling you can use**  
    Try **Apache Directory Studio** for an easy GUI to inspect your directory tree.

* * *

Security checklist
------------------

*   Put Guacamole behind a reverse proxy and **enable HTTPS**
*   Turn on **BAN** and **RESTRICT** to reduce brute force and control access windows
*   Prefer central auth (**LDAP/SSO**) + **TOTP**
*   Keep images up to date within a vetted minor line (e.g., 1.6.x)
*   Back up the DB and the `recordings/` volume

* * *

Contributing
------------


Thanks to all contributors:  
[![Contributors](https://contrib.rocks/image?repo=lhlaib/guacamole-docker)](https://github.com/lhlaib/guacamole-docker/graphs/contributors)



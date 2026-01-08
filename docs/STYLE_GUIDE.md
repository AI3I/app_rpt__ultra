# Documentation Style Guide

This guide ensures consistent formatting across all app_rpt__ultra documentation.

## Formatting Standards

### Project Names

| Item | Format | Example |
|------|--------|---------|
| This project | `app_rpt__ultra` | Welcome to `app_rpt__ultra` |
| Upstream project | `app_rpt` | Based on Asterisk `app_rpt` |
| External projects | *Italics* | *Asterisk*, *AllStarLink* |

### File Names and Scripts

| Item | Format | Example |
|------|--------|---------|
| Script names | `script.sh` | Run `install.sh` to begin |
| Config files | `config.ini` | Edit `config.ini` file |
| System files | `rpt.conf` | Located in `rpt.conf` |
| Any file reference | `filename` | See `README.md` |

### Paths and Directories

| Item | Format | Example |
|------|--------|---------|
| File paths | `/path/to/file` | Located at `/opt/app_rpt/bin/` |
| Directories | `/directory/` | Check `/var/log/` directory |
| Relative paths | `./script` | Run `./install.sh` |

### Commands and Code

| Item | Format | Example |
|------|--------|---------|
| Shell commands | `command` | Use `sudo systemctl restart asterisk` |
| DTMF commands | `*3` | Press `*3` to change state |
| Variables | `VARIABLE` | Set `MYNODE=1234` |
| Code blocks | \`\`\`bash ... \`\`\` | See examples below |

### System Components

| Item | Format | Example |
|------|--------|---------|
| System states | **Bold** | **Nighttime Operations** mode |
| Message slots | `slot NN` | Message `slot 70` contains weather |
| Asterisk CLI | `command` | Run `rpt stats 12345` |
| Services | `service.service` | The `kerchunkd.service` daemon |

### Emphasis and Terminology

| Item | Format | Example |
|------|--------|---------|
| First mention of term | **Bold** | The **hub node** coordinates... |
| Emphasis | *Italics* or **Bold** | This is *very* important |
| Warnings | > [!WARNING] | See examples |
| Notes | > [!NOTE] | See examples |

## Examples

### ✅ Correct

```markdown
The `install.sh` script installs `app_rpt__ultra` to `/opt/app_rpt/`.

Edit the `config.ini` file to set your `MYNODE` variable.

Run `statekeeper.sh` to change system states.

The **hub node** uses `configkeeper.sh` to sync with child nodes.
```

### ❌ Incorrect

```markdown
The install.sh script installs app_rpt__ultra to /opt/app_rpt/.

Edit the config.ini file to set your MYNODE variable.

Run _statekeeper.sh_ to change system states.

The hub node uses configkeeper.sh to sync with child nodes.
```

## Special Cases

### Asterisk vs asterisk

- `Asterisk` (capital A, no formatting) = The software project
- `asterisk` (lowercase, code formatting) = The system user account
- *Asterisk* (italics) = When referring to the project by name in prose

### app_rpt variations

- `app_rpt__ultra` = This project (always with double underscore)
- `app_rpt` = Upstream Asterisk app_rpt module
- `/opt/app_rpt/` = Installation directory path

### File extensions

Always include the extension:
- ✅ `install.sh`
- ❌ install
- ✅ `config.ini`
- ❌ config

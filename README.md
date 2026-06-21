# Linux File Permission and Ownership Auditor

A Linux support toolkit for auditing risky file permissions and applying targeted, guarded ownership and mode repairs.

## Audit script

```bash
chmod +x src/file_permission_auditor.sh
sudo ./src/file_permission_auditor.sh --path / --max-results 5000
```

## Repair script

```bash
chmod +x src/file_permission_repair.sh
sudo ./src/file_permission_repair.sh --path /srv/app --remove-world-write --dry-run
```

Examples:

```bash
sudo ./src/file_permission_repair.sh --path /srv/app/config.ini --mode 640
sudo ./src/file_permission_repair.sh --path /srv/app --owner appuser --group appgroup --recursive
sudo ./src/file_permission_repair.sh --path /srv/shared --set-sticky
sudo ./src/file_permission_repair.sh --path /srv/app --remove-world-write --recursive
```

## What the repair does

- Changes owner, group or mode only on an explicitly selected target.
- Can remove world-write permission.
- Can add the sticky bit to a selected directory.
- Supports recursive owner/group or world-write repair while refusing dangerous top-level recursive targets.
- Records original metadata and captures before-and-after evidence.
- Refuses symbolic-link targets.
- Supports dry-run, confirmation prompts, logs and clear exit codes.

## Safety

Recursive permission repair can affect application behaviour. Review the audit output first and target only paths whose expected ownership and permissions are known.

## Author

Dewald Pretorius — L2 IT Support Engineer

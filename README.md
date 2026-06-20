# Linux File Permission and Ownership Auditor

A read-only Bash toolkit for auditing world-writable files, orphaned ownership, SUID/SGID binaries, sensitive-file modes, and risky directory permissions.

## Usage

```bash
chmod +x src/file_permission_auditor.sh
sudo ./src/file_permission_auditor.sh --path / --max-results 5000
```

## Checks performed

- World-writable files and directories
- Files without valid user or group ownership
- SUID and SGID executables
- Sticky-bit coverage on shared writable directories
- Permissions on sensitive account, SSH, sudo, cron, and service files
- Text, CSV, and JSON reports

## Safety

The script does not change ownership, permissions, ACLs, extended attributes, or security contexts.

## Author

Dewald Pretorius — L2 IT Support Engineer

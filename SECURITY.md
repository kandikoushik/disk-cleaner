# Security Policy

## 🛡️ Safety & Security Guarantees

Disk Cleaner is designed with strict security boundaries:
- **Zero Telemetry / Offline**: Contains 0 network calls, analytics scripts, or background servers.
- **`Cleaner.allowed()` Safety Gate**: Every single deletion operation passes through a central safety check refusing paths outside `$HOME` and protecting `$HOME` root itself.
- **Trash-First Deletion**: All deletions move items to Finder Trash by default.
- **Guarded Process Shield**: Prevents quitting system daemons or processes owned by other users.

---

## 📩 Reporting a Vulnerability

If you discover a security vulnerability or safety bypass in Disk Cleaner, please report it privately:

1. **Email**: Open a security report directly to the maintainer or report via [GitHub Security Advisories](https://github.com/kandikoushik/disk-cleaner/security/advisories).
2. **Response Time**: We will review and respond to reports within 48 hours.

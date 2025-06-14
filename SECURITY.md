# Security Guide - Not a cPanel

This document outlines the security measures implemented in Not a cPanel and best practices for secure deployment.

## Security Improvements Made

### 1. Authentication & Authorization

- **Removed hardcoded credentials** from all files
- **Implemented secure password hashing** using Werkzeug's PBKDF2
- **Added rate limiting** on login attempts (5 attempts per minute)
- **Account lockout mechanism** after 5 failed attempts (15-minute lockout)
- **Session timeout** with configurable duration (default: 4 hours)
- **Secure session management** with proper token generation

### 2. Input Validation & Sanitization

- **Regex validation** for container names, image names, ports, and database names
- **Input length limits** to prevent buffer overflow attacks
- **Command sanitization** to prevent injection attacks
- **SQL parameterization** to prevent SQL injection

### 3. Command Execution Security

- **Eliminated shell=True** from subprocess calls
- **Command whitelisting** for allowed operations
- **Input sanitization** for all command parameters
- **Timeout controls** to prevent hanging processes

### 4. Configuration Security

- **Secure configuration files** using INI format instead of Python execution
- **Environment variable support** for sensitive data
- **File permission controls** (600 permissions on config files)
- **Default secure settings** with production-ready defaults

### 5. Network Security

- **CORS restrictions** with explicit origin allowlist
- **Localhost binding** by default (127.0.0.1 instead of 0.0.0.0)
- **HTTPS support** (configurable)
- **Secure headers** implementation

### 6. Logging & Monitoring

- **Comprehensive logging** of security events
- **Failed login attempt tracking**
- **Security event monitoring**
- **Log file rotation** and management

## Installation Security

### Secure Installation

1. **Use the secure startup script**:
   ```bash
   python run_secure.py
   ```

2. **Set strong passwords** when prompted

3. **Secure file permissions**:
   ```bash
   chmod 600 config.ini
   chmod 700 logs/
   ```

4. **Update dependencies** regularly:
   ```bash
   pip install --upgrade -r requirements.txt
   ```

### Production Deployment

1. **Use HTTPS** in production:
   - Set `force_https = True` in config.ini
   - Configure reverse proxy (nginx/Apache) with SSL

2. **Run with minimal privileges**:
   - Create dedicated user account
   - Avoid running as root

3. **Database security**:
   - Use strong database passwords
   - Restrict database access to localhost
   - Enable database logging

4. **Firewall configuration**:
   ```bash
   # Allow only necessary ports
   ufw allow ssh
   ufw allow 5000  # Or your configured port
   ufw enable
   ```

## Security Configuration

### config.ini Security Settings

```ini
[security]
debug = False                    # Never enable in production
force_https = True              # Enable for production
session_timeout_hours = 4       # Adjust based on needs
max_login_attempts = 5          # Prevent brute force
lockout_duration_minutes = 15   # Account lockout duration
```

### Environment Variables

```bash
export SECRET_KEY=your_secret_key_here
export DB_PASSWORD=your_db_password
export ADMIN_PASSWORD_HASH=your_hashed_password
```

## Security Best Practices

### For Administrators

1. **Use strong passwords** (minimum 12 characters, mixed case, numbers, symbols)
2. **Enable two-factor authentication** (when available)
3. **Regular security updates** for all components
4. **Monitor logs** for suspicious activity
5. **Backup configurations** securely
6. **Limit network access** to trusted IPs only

### For Developers

1. **Never commit secrets** to version control
2. **Use environment variables** for sensitive data
3. **Validate all inputs** on both client and server side
4. **Follow secure coding practices**
5. **Regular security audits** of dependencies

## Known Security Considerations

### Current Limitations

1. **No built-in 2FA** - Consider adding external 2FA
2. **Basic role management** - Single admin user only
3. **No audit trail** - Limited to basic logging
4. **Docker socket access** - Inherent security risk

### Mitigation Strategies

1. **Network isolation** - Run in isolated network segment
2. **Regular monitoring** - Monitor Docker and system logs
3. **Access controls** - Limit who can access the control panel
4. **Backup strategy** - Regular backups of configurations

## Incident Response

### Security Incident Checklist

1. **Isolate the system** - Disconnect from network if needed
2. **Check logs** - Review security and application logs
3. **Change passwords** - Reset all authentication credentials
4. **Update system** - Apply all security patches
5. **Review access** - Audit who had access to the system
6. **Document incident** - Keep records for future reference

### Log Locations

- Application logs: `not_a_cpanel.log`
- System logs: `/var/log/syslog` (Linux)
- Docker logs: `docker logs <container_name>`

## Security Updates

Regularly check for security updates:

1. **Python packages**: `pip list --outdated`
2. **System packages**: `apt list --upgradable` (Ubuntu/Debian)
3. **Docker images**: `docker images --filter dangling=true`

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do not** create a public issue
2. **Email** security concerns privately
3. **Provide** detailed information about the vulnerability
4. **Wait** for acknowledgment before public disclosure

## Security Checklist

- [ ] Strong admin password set
- [ ] Debug mode disabled in production
- [ ] HTTPS enabled for production
- [ ] Firewall properly configured
- [ ] Regular backups configured
- [ ] Log monitoring in place
- [ ] Dependencies up to date
- [ ] File permissions properly set
- [ ] Network access restricted
- [ ] Security documentation reviewed

---

**Remember**: Security is an ongoing process, not a one-time setup. Regularly review and update your security measures.


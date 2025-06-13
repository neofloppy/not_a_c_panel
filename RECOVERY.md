# Recovery Guide - Installation Conflict Resolution

If you encounter the error "Your local changes to the following files would be overwritten by merge", here's how to fix it:

## Quick Fix (Recommended)

Run this command in your terminal:

```bash
# Navigate to the installation directory
cd ~/not_a_c_panel

# Backup your local changes
git stash push -m "Backup before update $(date)"

# Pull the latest updates
git pull origin master

# Make scripts executable
chmod +x *.sh

# Run the updated setup
./setup.sh
```

## Alternative: Use the Fix Script

Download and run the fix script:

```bash
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/fix-install.sh -o fix-install.sh
chmod +x fix-install.sh
./fix-install.sh
```

## Manual Resolution

If the above doesn't work, you can manually resolve:

```bash
cd ~/not_a_c_panel

# Option 1: Keep your changes and merge
git stash
git pull origin master
git stash pop  # This will restore your changes

# Option 2: Discard local changes and use latest
git reset --hard HEAD
git pull origin master

# Option 3: Fresh installation
cd ~
rm -rf not_a_c_panel
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh | bash
```

## What Caused This?

This happens when:
1. You previously installed Not a cPanel
2. Made local modifications to files (like setup.sh)
3. Tried to update, but Git detected conflicts

## Prevention

The updated install script now automatically handles this by:
- Detecting local changes
- Backing them up with `git stash`
- Pulling updates cleanly
- Providing recovery options

## After Recovery

Once fixed, you can:

1. **Start the control panel:**
   ```bash
   cd ~/not_a_c_panel
   python3 server.py
   ```

2. **Access the interface:**
   - URL: http://localhost:5000
   - Username: admin
   - Password: docker123!

3. **Check your backed-up changes:**
   ```bash
   git stash list  # See your backups
   git stash show  # Preview changes
   git stash pop   # Restore if needed
   ```

## Need Help?

If you're still having issues:
1. Check the main README.md
2. Review the DEPLOYMENT.md guide
3. Run the test script: `./test-setup.sh`
4. Create an issue on GitHub
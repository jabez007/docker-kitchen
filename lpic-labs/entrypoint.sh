#!/bin/bash

# LPIC-1 Lab Environment Startup Script
# This script starts essential services and keeps the container running

set -euo pipefail

echo "Starting LPIC-1 Lab Environment..."

# Start SSH daemon for remote access practice
if [ -f /usr/sbin/sshd ]; then
    echo "Starting SSH daemon..."
    sudo /usr/sbin/sshd -D
fi

# Start rsyslog for logging practice
if [ -f /usr/sbin/rsyslogd ]; then
    echo "Starting rsyslog daemon..."
    sudo /usr/sbin/rsyslogd
fi

# Start cron daemon for scheduling practice
if [ -f /usr/sbin/cron ]; then
    echo "Starting cron daemon..."
    sudo /usr/sbin/cron
fi

# Start Apache2 for web server practice
if [ -f /usr/sbin/apache2ctl ]; then
    echo "Starting Apache2..."
    sudo /usr/sbin/apache2ctl start
fi

# Start MariaDB for database practice
if [ -f /usr/bin/mysqld_safe ]; then
    echo "Starting MariaDB..."
    sudo /usr/bin/mysqld_safe --user=mysql &
fi

echo "Services started. LPIC-1 Lab Environment is ready!"
echo "You can now attach to this container with: docker exec -it <container_name> bash"
echo "Available services: SSH, rsyslog, cron, Apache2, MariaDB"

# Keep the container running by tailing a log file or sleeping
# This allows users to attach while keeping services active
if [ -f /var/log/syslog ]; then
    exec tail -F /var/log/syslog
else
    # Fallback: just keep the container alive
    exec sleep infinity
fi

#!/usr/bin/env python3
import os
import socket
import sys
import time
import configparser


def get_config():
    """Read configuration from expected locations and return (config, path)"""
    config = configparser.ConfigParser()
    config_paths = [
        "/home/mesh/bbs/config.ini",
        "/home/mesh/bbs/config/config.ini",
        "config.ini",
    ]
    for path in config_paths:
        if os.path.exists(path):
            try:
                config.read(path)
                return config, path
            except Exception as e:
                print(f"Error reading config at {path}: {e}")
    return None, None


def check_meshtastic_connection(host="localhost", port=4403):
    """Test if the meshtastic TCP API port is open and accepting connections"""
    s = None
    try:
        # Use create_connection for better IPv4/IPv6 compatibility and built-in timeout
        s = socket.create_connection((host, port), timeout=3)
        return True
    except (OSError, socket.timeout) as e:
        print(f"Connection test to {host}:{port} failed: {e}")
        return False
    finally:
        if s:
            s.close()


def check_process_health():
    """Check if server.py process is running and responsive"""
    try:
        # Check if main process exists
        # In Docker, the entrypoint.sh might be PID 1, and server.py might be a child
        # or replaced by exec. Let's look for any process named server.py
        if not os.path.exists('/proc'):
            print("Error: /proc filesystem not found. Cannot check process health.")
            return False
            
        pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
        if not pids:
            print("Error: No processes found in /proc.")
            return False

        found = False
        for pid in pids:
            try:
                with open(os.path.join('/proc', pid, 'cmdline'), 'rb') as f:
                    cmdline = f.read().decode('utf-8', errors='ignore')
                    if 'server.py' in cmdline:
                        print(f"Found server.py process at PID {pid}")
                        try:
                            # Test if process is responsive
                            os.kill(int(pid), 0)
                            print(f"Process {pid} is responsive (signal 0 passed)")
                        except PermissionError:
                            # If we can't signal it but it exists, consider it found
                            print(f"Process {pid} exists but permission denied for signaling")
                            pass
                        found = True
                        break
            except (OSError, IOError):
                continue
        
        if not found:
            print(f"server.py process not found after scanning {len(pids)} PIDs")
            return False
    except OSError as e:
        print(f"Process check failed during /proc scan: {e}")
        return False
    else:
        return True


# Run health checks
config, config_path = get_config()
if config_path:
    print(f"Using configuration from: {config_path}")
else:
    print("No configuration file found, using defaults.")

interface_type = "serial"
hostname = "localhost"
tcp_port = 4403

if config and 'interface' in config:
    interface_type = config['interface'].get('type', 'serial').lower()
    hostname = config['interface'].get('hostname', 'localhost')
    # Try to get port, default to 4403 for TCP
    try:
        tcp_port = config['interface'].getint('port', 4403)
    except ValueError:
        tcp_port = 4403

print(f"Detected interface: {interface_type}")

if interface_type == "tcp":
    print(f"Running TCP connection health check to {hostname}:{tcp_port}...")
    connection_ok = False
    max_attempts = 3
    for attempt in range(max_attempts):
        if check_meshtastic_connection(host=hostname, port=tcp_port):
            connection_ok = True
            print(f"Connection test attempt {attempt + 1}: PASS")
            break
        else:
            print(f"Connection test attempt {attempt + 1}: FAIL")
            if attempt < max_attempts - 1:
                time.sleep(1)
    
    if not connection_ok:
        print("All connection attempts failed")
        sys.exit(1)
    
    # Second gate: Ensure process is also healthy
    print("Running process health check...")
    if not check_process_health():
        print("Process health check failed")
        sys.exit(1)
else:
    print("Skipping TCP check for serial/unknown interface. Running process health check...")
    if not check_process_health():
        print("Process health check failed")
        sys.exit(1)

print("All health checks passed")
sys.exit(0)

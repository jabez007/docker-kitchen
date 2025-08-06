#!/usr/bin/env python3
import socket
import sys
import time

# Test connection to meshtasticd with multiple attempts
for attempt in range(3):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(3)
        s.connect(("localhost", 4403))
        test_data = b"\x94\xc3\x00\x00"  # Simple protobuf header
        s.send(test_data)
        s.close()

        print(f"Connection test {attempt + 1} passed")
        break
    except (ConnectionRefusedError, ConnectionResetError, BrokenPipeError) as e:
        print(f"Connection test {attempt + 1} failed: {e}")
        if attempt == 2:
            sys.exit(1)
        time.sleep(1)
    except Exception as e:
        print(f"Unexpected error on attempt {attempt + 1}: {e}")
        if attempt == 2:
            sys.exit(1)
        time.sleep(1)

# Check if the main process is running
try:
    with open("/proc/1/cmdline", "rb") as f:
        cmdline = f.read().decode("utf-8", errors="ignore")
        if "server.py" not in cmdline:
            print("server.py not running as PID 1")
            sys.exit(1)
except Exception as e:
    print(f"Process check failed: {e}")
    sys.exit(1)

print("All health checks passed")

#!/usr/bin/env python3
"""
Error Prevention and Monitoring Script
Monitors for common errors and prevents infinite loops
"""

import psutil
import time
import json
import logging
from datetime import datetime
import signal
import sys


class ErrorMonitor:
    def __init__(self, max_cpu_percent=90, max_memory_percent=85, check_interval=5):
        self.max_cpu_percent = max_cpu_percent
        self.max_memory_percent = max_memory_percent
        self.check_interval = check_interval
        self.running = True
        self.start_time = time.time()

        # Setup logging
        logging.basicConfig(
            filename="error_monitor.log",
            level=logging.INFO,
            format="%(asctime)s - %(levelname)s - %(message)s",
        )

        # Setup signal handlers
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

    def signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        print(f"\nReceived signal {signum}, shutting down...")
        self.running = False
        sys.exit(0)

    def check_system_resources(self):
        """Monitor system resources to detect runaway processes"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory_percent = psutil.virtual_memory().percent

            if cpu_percent > self.max_cpu_percent:
                warning = f"High CPU usage detected: {cpu_percent}%"
                print(warning)
                logging.warning(warning)
                return False

            if memory_percent > self.max_memory_percent:
                warning = f"High memory usage detected: {memory_percent}%"
                print(warning)
                logging.warning(warning)
                return False

            return True

        except Exception as e:
            logging.error(f"Error checking system resources: {e}")
            return True

    def check_process_runtime(self, max_runtime_minutes=30):
        """Check if processes have been running too long"""
        current_time = time.time()
        runtime = (current_time - self.start_time) / 60  # Convert to minutes

        if runtime > max_runtime_minutes:
            warning = f"Process has been running for {runtime:.1f} minutes"
            print(warning)
            logging.warning(warning)
            return False

        return True

    def monitor_log_files(self, log_files=["execution.log", "error_monitor.log"]):
        """Monitor log files for error patterns"""
        error_patterns = [
            "infinite loop",
            "recursion limit",
            "memory error",
            "timeout",
            "connection refused",
            "maximum retries exceeded",
        ]

        for log_file in log_files:
            try:
                with open(log_file, "r") as f:
                    content = f.read().lower()
                    for pattern in error_patterns:
                        if pattern in content:
                            warning = f"Error pattern '{pattern}' found in {log_file}"
                            print(warning)
                            logging.warning(warning)
                            return False
            except FileNotFoundError:
                pass  # Log file doesn't exist yet
            except Exception as e:
                logging.error(f"Error reading log file {log_file}: {e}")

        return True

    def run_monitoring(self):
        """Main monitoring loop with proper exit conditions"""
        print("Starting error monitoring...")
        logging.info("Error monitoring started")

        while self.running:
            try:
                # Check system resources
                if not self.check_system_resources():
                    print("System resource limits exceeded!")
                    break

                # Check runtime
                if not self.check_process_runtime():
                    print("Maximum runtime exceeded!")
                    break

                # Check log files
                if not self.monitor_log_files():
                    print("Error patterns detected in logs!")
                    break

                # Wait before next check
                time.sleep(self.check_interval)

            except KeyboardInterrupt:
                print("\nMonitoring stopped by user")
                break
            except Exception as e:
                logging.error(f"Monitoring error: {e}")
                time.sleep(self.check_interval)

        print("Error monitoring stopped")
        logging.info("Error monitoring stopped")


if __name__ == "__main__":
    monitor = ErrorMonitor()
    monitor.run_monitoring()

# Reading error_monitor.py to check for errors

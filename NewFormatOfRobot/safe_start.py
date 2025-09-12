#!/usr/bin/env python3
"""
Safe Startup Script - Prevents common errors and infinite loops
"""

import json
import sys
import time
import signal
import subprocess
import threading
from pathlib import Path
import os
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("execution.log"),
        logging.StreamHandler(sys.stdout),
    ],
)


class SafeStartup:
    def __init__(self, config_file="config.json"):
        self.config = self.load_config(config_file)
        self.processes = []
        self.running = True

        # Setup signal handlers
        signal.signal(signal.SIGINT, self.shutdown)
        signal.signal(signal.SIGTERM, self.shutdown)

    def load_config(self, config_file):
        """Load configuration with error handling"""
        try:
            with open(config_file, "r") as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Config file {config_file} not found, using defaults")
            return self.get_default_config()
        except json.JSONDecodeError as e:
            print(f"Invalid JSON in config file: {e}")
            return self.get_default_config()

    def get_default_config(self):
        """Default configuration to prevent errors"""
        return {
            "error_prevention": {
                "max_execution_time_minutes": 30,
                "max_retry_attempts": 3,
                "request_timeout_seconds": 30,
            },
            "server_config": {"host": "localhost", "port": 5000, "debug": False},
        }

    def validate_environment(self):
        """Check environment before starting"""
        errors = []

        # Check Python version
        if sys.version_info < (3, 7):
            errors.append("Python 3.7+ required")

        # Check required files exist
        required_files = ["server.py", "requirements.txt"]
        for file in required_files:
            if not Path(file).exists():
                errors.append(f"Required file missing: {file}")

        # Check if ports are available
        import socket

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(
                ("localhost", self.config["server_config"]["port"])
            )
            if result == 0:
                errors.append(
                    f"Port {self.config['server_config']['port']} already in use"
                )
            sock.close()
        except Exception as e:
            errors.append(f"Port check failed: {e}")

        return errors

    def start_with_timeout(self, command, timeout_minutes=30):
        """Start process with automatic timeout"""

        def timeout_handler():
            time.sleep(timeout_minutes * 60)
            if self.running:
                print(f"Timeout reached ({timeout_minutes} minutes), shutting down...")
                self.shutdown(None, None)

        # Start timeout thread
        timeout_thread = threading.Thread(target=timeout_handler)
        timeout_thread.daemon = True
        timeout_thread.start()

        # Start the actual process
        try:
            process = subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            self.processes.append(process)
            return process
        except Exception as e:
            print(f"Failed to start process: {e}")
            return None

    def monitor_process(self, process):
        """Monitor process for errors and infinite loops"""
        start_time = time.time()
        max_runtime = self.config["error_prevention"]["max_execution_time_minutes"] * 60

        while process.poll() is None and self.running:
            # Check if process has been running too long
            if time.time() - start_time > max_runtime:
                print("Process exceeded maximum runtime, terminating...")
                process.terminate()
                break

            time.sleep(1)

        return process.returncode

    def shutdown(self, signum, frame):
        """Graceful shutdown"""
        print("\nShutting down safely...")
        self.running = False

        for process in self.processes:
            try:
                process.terminate()
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
            except Exception as e:
                print(f"Error terminating process: {e}")

        sys.exit(0)

    def run(self):
        """Main execution with error prevention"""
        print("Starting safe execution...")

        # Validate environment
        errors = self.validate_environment()
        if errors:
            print("Environment validation failed:")
            for error in errors:
                print(f"  - {error}")
            return False

        # Start error monitor in background
        monitor_process = self.start_with_timeout("python error_monitor.py", 60)

        # Start main server
        server_process = self.start_with_timeout("python server.py", 30)

        if server_process:
            print("Server started successfully")
            return_code = self.monitor_process(server_process)
            print(f"Server exited with code: {return_code}")
        else:
            print("Failed to start server")

        return True


def safe_start():
    """Safely start the Robot Framework testing system"""
    try:
        logging.info("Starting Robot Framework testing system...")

        # Check if required files exist
        required_files = ["server.py", "config.json", "requirements.txt"]
        for file in required_files:
            if not os.path.exists(file):
                raise FileNotFoundError(f"Required file {file} not found")

        # Start the server
        process = subprocess.Popen([sys.executable, "server.py"])
        logging.info(f"Server started with PID: {process.pid}")

        return process

    except Exception as e:
        logging.error(f"Error starting system: {e}")
        raise


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    logging.info("Received shutdown signal, cleaning up...")
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        startup = SafeStartup()
        startup.run()
    except KeyboardInterrupt:
        logging.info("Interrupted by user")
    except Exception as e:
        logging.error(f"Fatal error: {e}")
        sys.exit(1)

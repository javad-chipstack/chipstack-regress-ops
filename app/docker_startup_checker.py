#!/usr/bin/env python3
import subprocess
import threading
import time
import datetime
import logging
from datetime import timedelta

# Configure logging


class DockerStartupMonitor:
    def __init__(self, outdir: str, target_message="Application startup complete."):
        self.target_message = target_message
        self.startup_detected = False
        self.start_time = datetime.datetime.now()
        self.twenty_min_timeout = self.start_time + datetime.timedelta(minutes=20)
        self.monitor_thread = None

        self.logger = logging.getLogger("docker_startup_monitor")

        self.logger.setLevel(logging.INFO)
        for handler in self.logger.handlers[:]:
            self.logger.removeHandler(handler)
        log_file_path = f"{outdir}/docker_startup_monitor.log"
        self.logger.addHandler(logging.FileHandler(log_file_path))
        # self.logger.addHandler(logging.StreamHandler())
        self.logger.propagate = False

    def check_git_logs(self):
        self.logger.info(
            f"Monitoring started at {self.start_time}. Will timeout at {self.twenty_min_timeout}."
        )
        while datetime.datetime.now() < self.twenty_min_timeout:
            try:
                # Calculate elapsed time in a human-readable format
                elapsed_time = datetime.datetime.now() - self.start_time
                elapsed_time_readable = str(
                    timedelta(seconds=int(elapsed_time.total_seconds()))
                )

                # Calculate remaining time in a human-readable format
                remaining_time = self.twenty_min_timeout - datetime.datetime.now()
                remaining_time_readable = str(
                    timedelta(seconds=int(remaining_time.total_seconds()))
                )

                result = subprocess.run(
                    ["docker", "logs", "--since", "1m", "server-server-1"],
                    capture_output=True,
                    text=True,
                    check=False,
                )

                # Check if target message is in the log output
                if (
                    self.target_message in result.stdout
                    or self.target_message in result.stderr
                ):
                    self.logger.info(f"Found target message: '{self.target_message}'")
                    self.startup_detected = True
                    return

                self.logger.info(
                    f"Target message not found, rechecking in 5 seconds... "
                    f"Elapsed: {elapsed_time_readable}, Remaining: {remaining_time_readable}."
                )

                # Log stderr if it contains any errors
                if result.stderr:
                    indented_stderr = "\n".join(
                        ["    " + line for line in result.stderr.splitlines()]
                    )
                    self.logger.error(f"stderr output:\n{indented_stderr}")

                time.sleep(5)

            except subprocess.SubprocessError as e:
                self.logger.error(f"Error running git command: {e}")
                return

        # If we reach here, 20 minutes have elapsed without finding the message
        self.logger.warning(
            f"20-minute timeout elapsed. Message not found: '{self.target_message}'"
        )

    def start_monitoring(self):
        self.logger.info("Starting git log monitoring in background...")

        # Create and start background thread
        self.monitor_thread = threading.Thread(target=self.check_git_logs, daemon=True)
        self.monitor_thread.start()

        return self.monitor_thread


if __name__ == "__main__":
    monitor = DockerStartupMonitor()
    monitor.start_monitoring()
    time.sleep(60 * 20)
    print("Startup detected" if monitor.startup_detected else "Startup not detected")

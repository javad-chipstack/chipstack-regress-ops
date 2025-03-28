import docker
import logging
import threading
import time
from pathlib import Path
from datetime import datetime


class DockerLogger:
    """
    A class to attach to a Docker container and log its output.
    Ensures logs are saved even if logging stops unexpectedly.
    """

    def __init__(self, container_id, log_dir="docker_logs"):
        """
        Initialize the Docker logger.

        Args:
            container_id (str): ID or name of the Docker container to log
            log_dir (str): Directory to store log files
        """
        self.container_id = container_id
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True, parents=True)

        # Setup Docker client
        self.client = docker.from_env()

        # Initialize logger
        self.logger = self._setup_logger()

        # Threading control
        self.stop_event = threading.Event()
        self.logging_thread = None

    def _setup_logger(self):
        """Set up and configure the logger."""
        # Create a timestamp for the log filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = self.log_dir / f"{self.container_id}_{timestamp}.log"

        # Configure logger
        logger = logging.getLogger(f"docker_logger_{self.container_id}")
        logger.setLevel(logging.INFO)

        # Remove existing handlers to avoid duplicates on re-initialization
        for handler in logger.handlers[:]:
            logger.removeHandler(handler)

        # Create file handler with immediate flush
        file_handler = logging.FileHandler(log_file, "w")
        file_handler.setLevel(logging.INFO)

        # Create formatter and add it to the handler
        formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
        file_handler.setFormatter(formatter)

        # Add handler to logger
        logger.addHandler(file_handler)

        return logger

    def start_logging(self):
        """
        Start logging the Docker container's output.
        This method runs in a separate thread to avoid blocking.
        """
        if self.logging_thread and self.logging_thread.is_alive():
            self.logger.warning("Logging already in progress")
            return

        self.stop_event.clear()
        self.logging_thread = threading.Thread(target=self._logging_worker)
        self.logging_thread.daemon = (
            True  # Allow the thread to exit when the main program exits
        )
        self.logging_thread.start()

        self.logger.info(f"Started logging container: {self.container_id}")

    def _logging_worker(self):
        """Worker thread function that performs the actual logging."""
        try:
            # Get container
            container = self.client.containers.get(self.container_id)

            # Log container info
            self.logger.info(f"Container name: {container.name}")
            self.logger.info(f"Container status: {container.status}")

            # Start container logs stream with timestamps
            log_stream = container.logs(stream=True, follow=True, timestamps=True)

            # Process logs until stop_event is set
            for log_line in log_stream:
                if self.stop_event.is_set():
                    break

                # Decode log line
                try:
                    log_line = log_line.decode("utf-8").strip()
                    self.logger.info(log_line)
                except UnicodeDecodeError:
                    self.logger.warning("Failed to decode log line")

        except docker.errors.NotFound:
            self.logger.error(f"Container {self.container_id} not found")
        except docker.errors.APIError as e:
            self.logger.error(f"Docker API error: {str(e)}")
        except Exception as e:
            self.logger.error(f"Unexpected error: {str(e)}")
        finally:
            self.logger.info(f"Stopped logging container: {self.container_id}")

    def stop_logging(self):
        """Stop the logging process gracefully."""
        if not self.logging_thread or not self.logging_thread.is_alive():
            self.logger.warning("No active logging to stop")
            return

        self.stop_event.set()
        self.logging_thread.join(
            timeout=5
        )  # Wait for the thread to finish, with timeout

        if self.logging_thread.is_alive():
            self.logger.warning("Logging thread did not terminate gracefully")
        else:
            self.logger.info("Logging stopped successfully")


# Example usage
if __name__ == "__main__":
    # Create a logger for a container
    docker_logger = DockerLogger("server-server-1")

    # Start logging
    docker_logger.start_logging()

    try:
        # Your application code here
        time.sleep(60)  # Log for 60 seconds
    finally:
        # Ensure logging is stopped properly
        docker_logger.stop_logging()

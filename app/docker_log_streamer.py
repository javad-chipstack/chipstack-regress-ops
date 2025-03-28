import docker
import threading
import logging
import time
from datetime import datetime


class DockerLogStreamer:
    def __init__(
        self,
        container_name,
        outdir: str,
        start_time=None,
        check_interval=5,
    ):
        self.container_name = container_name
        self.log_file = f"{outdir}/docker_log_streamer.log"

        print(f"INFO: Log file: {self.log_file}", flush=True)

        self.check_interval = (
            check_interval  # Time interval (seconds) to check for restarts
        )
        self.start_time = start_time
        self.client = docker.from_env()
        self.thread = None
        self.stop_event = threading.Event()

        # Configure logging
        logging.basicConfig(
            filename=self.log_file,
            level=logging.INFO,
            format="%(asctime)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        self.logger = logging.getLogger(__name__)
        if self.start_time and isinstance(self.start_time, str):
            # Convert string start_time to datetime
            self.start_time = datetime.strptime(self.start_time, "%Y-%m-%d %H:%M:%S")

        if self.start_time:
            self.start_time = self.start_time.strftime("%Y-%m-%dT%H:%M:%S")

    def get_container(self):
        """Fetch the latest container instance to handle restarts."""
        try:
            return self.client.containers.get(self.container_name)
        except docker.errors.NotFound:
            self.logger.error(f"Container '{self.container_name}' not found.")
            return None

    def stream_logs(self):
        """Continuously stream logs, handling container restarts."""
        while not self.stop_event.is_set():
            container = self.get_container()
            if container is None:
                self.logger.warning("Waiting for container to be available...")
                time.sleep(self.check_interval)
                continue

            try:
                for line in container.logs(
                    stream=True, follow=True, since=self.start_time
                ):
                    if self.stop_event.is_set():
                        break
                    decoded_line = line.decode("utf-8").strip()
                    self.logger.info(decoded_line)
                    # print(decoded_line)  # Optional: Print to console
            except (docker.errors.NotFound, docker.errors.APIError) as e:
                self.logger.error(f"Lost connection to container: {e}. Reconnecting...")
                time.sleep(self.check_interval)  # Wait before retrying

    def start(self):
        """Starts log streaming in a separate thread with auto-reconnect."""
        if self.thread and self.thread.is_alive():
            print("Log streaming is already running.")
            return

        self.stop_event.clear()
        self.thread = threading.Thread(target=self.stream_logs, daemon=True)
        self.thread.start()
        print(f"Started log streaming for container: {self.container_name}")

    def stop(self):
        """Stops the log streaming thread gracefully."""
        self.stop_event.set()
        if self.thread:
            self.thread.join()
        print(f"Stopped log streaming for container: {self.container_name}")


if __name__ == "__main__":
    container_name = "server-server-1"  # Replace with actual container name
    log_streamer = DockerLogStreamer(container_name="server-server-1", start_time=None)

    try:
        log_streamer.start()
        while True:
            time.sleep(1000)  # Keep the main thread alive
    except KeyboardInterrupt:
        print("\nStopping log streaming...")
        log_streamer.stop()

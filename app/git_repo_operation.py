import os
import logging
import subprocess
import shlex
from pathlib import Path
import select


class GitDockerOperation:
    def __init__(
        self,
        target_branch="main",
        base_path="/home/javad/dev/chipstack-ai",
        server_path="/home/javad/dev/chipstack-ai/server",
        log_file=None,
    ):
        self.target_branch = target_branch
        self.base_path, self.server_path = Path(base_path), Path(server_path)
        if not self.base_path.exists() or not self.server_path.exists():
            raise FileNotFoundError(
                f"Paths not found: {self.base_path}, {self.server_path}"
            )

        log_file = log_file or "git_docker.log"
        self._setup_logger(log_file)
        self.logger.info(
            f"Initialized with base: {self.base_path}, server: {self.server_path}"
        )

    def _setup_logger(self, log_file):
        self.logger = logging.getLogger("git_docker_reset")
        self.logger.setLevel(logging.INFO)
        for handler in self.logger.handlers[:]:
            self.logger.removeHandler(handler)
        self.logger.addHandler(logging.FileHandler(log_file))
        self.logger.addHandler(logging.StreamHandler())

    def _run_command(self, command, cwd=None, shell=False):
        try:
            command = (
                shlex.split(command)
                if isinstance(command, str) and not shell
                else command
            )
            self.logger.info(f"Running command: {command} in {cwd or os.getcwd()}")

            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=cwd,
                shell=shell,
                bufsize=1,  # Line buffering
                universal_newlines=True,  # Ensures real-time output processing
            )

            stdout_lines, stderr_lines = [], []

            # Use select to monitor stdout & stderr without blocking
            while process.poll() is None:
                readable, _, _ = select.select(
                    [process.stdout, process.stderr], [], [], 0.1
                )

                for stream in readable:
                    line = stream.readline().strip()
                    if line:
                        if stream == process.stdout:
                            self.logger.info(f"\tstdout: {line}")
                            stdout_lines.append(line)
                        else:
                            self.logger.error(f"\tstderr: {line}")
                            stderr_lines.append(line)

            # Capture any remaining output after process exits
            for line in process.stdout.readlines():
                line = line.strip()
                if line:
                    self.logger.info(f"\tstdout: {line}")
                    stdout_lines.append(line)

            for line in process.stderr.readlines():
                line = line.strip()
                if line:
                    self.logger.error(f"\tstderr: {line}")
                    stderr_lines.append(line)

            return (
                process.returncode == 0,
                (
                    "\n".join(stdout_lines)
                    if process.returncode == 0
                    else "\n".join(stderr_lines)
                ),
            )

        except Exception as e:
            self.logger.error(f"Command failed: {e}")
            return False, str(e)

    def git_wrapper(self):
        self.logger.info(f"Starting Git operations for branch '{self.target_branch}'")
        os.chdir(self.base_path)

        commands = [
            "git stash push -m 'Auto-stash before reset'",
            "git checkout main",
            "git reset --hard origin/main",
            "git clean -fd",
            "git pull",
            f"git checkout {self.target_branch}",
            "git pull",
        ]

        for cmd in commands:
            success, _ = self._run_command(cmd)
            if not success:
                self.logger.error(
                    f"Git operation '{cmd}' failed. Aborting further Git steps."
                )
                return False

        self.logger.info("✅ Git operations completed")
        return True

    def hard_reset_docker(self):
        self.logger.info("Starting Docker reset")
        os.chdir(self.server_path)

        # Run each Docker command and stop if any fails
        commands = [
            "make stopdocker",
            "docker system prune -af",
            "make hardrestartdocker",
        ]

        for cmd in commands:
            success, _ = self._run_command(cmd)
            if not success:
                self.logger.warning(
                    f"Docker command '{cmd}' failed. Aborting remaining steps."
                )
                return False
        return True


if __name__ == "__main__":
    try:
        git_docker_operation = GitDockerOperation()
        if (
            not git_docker_operation.git_wrapper()
            or not git_docker_operation.hard_reset_docker()
        ):
            print("✅ PASS!")
        else:
            print("❌ FAILED: Check logs for details.")
    except Exception as e:
        git_docker_operation.logger.warning(f"Error: {e}", exc_info=True)
        print("❌ FAILED: Check logs for details.")

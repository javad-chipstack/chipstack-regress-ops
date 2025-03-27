import os
import logging
import subprocess
import shlex
from pathlib import Path
import select
from dotenv import load_dotenv

load_dotenv(dotenv_path="/home/javad/dev/chipstack-ai/server/.env")


class GitDockerOperation:
    def __init__(
        self,
        outdir: str,
        target_branch="main",
        base_path="/home/javad/dev/chipstack-ai",
        server_path="/home/javad/dev/chipstack-ai/server",
    ):
        self.target_branch = target_branch
        self.base_path, self.server_path = Path(base_path), Path(server_path)
        if not self.base_path.exists() or not self.server_path.exists():
            raise FileNotFoundError(
                f"Paths not found: {self.base_path}, {self.server_path}"
            )

        log_file = Path(outdir).joinpath("git_docker.log")
        log_file.parent.mkdir(parents=True, exist_ok=True)
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
        # self.logger.addHandler(logging.StreamHandler())
        self.logger.propagate = False

    def _run_command(self, command, cwd=None, shell=False):
        try:
            # If the command is a string and shell is False, split the command
            command = (
                shlex.split(command)
                if isinstance(command, str) and not shell
                else command
            )

            # Log the command being run
            self.logger.info(f"Running command: {command} in {cwd or os.getcwd()}")

            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=cwd,
                shell=shell,
            )

            stdout_lines = []
            stderr_lines = []

            while True:
                ready_to_read, _, _ = select.select(
                    [process.stdout, process.stderr], [], []
                )

                for stream in ready_to_read:
                    line = stream.readline().strip()
                    if line:
                        if stream is process.stdout:
                            self.logger.info(f"\tstdout: {line}")
                            stdout_lines.append(line.strip())
                        else:
                            self.logger.info(f"\tstderr: {line}")
                            stderr_lines.append(line.strip())

                if process.poll() is not None:
                    break

            # Wait for the process to finish and get the return code
            process.stdout.close()
            process.stderr.close()
            process.wait()

            # Check for process return code
            if process.returncode == 0:
                return True, "\n".join(stdout_lines)  # Return True and combined stdout
            else:
                return False, "\n".join(
                    stderr_lines
                )  # Return False and combined stderr

        except Exception as e:
            # Log any exceptions that occur
            self.logger.error(f"Command failed: {e}")
            return False, str(e)  # Return False and the error message

    def git_wrapper(self):
        self.logger.info(f"Starting git operations for branch '{self.target_branch}'")
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

        token = subprocess.check_output(
            ["gcloud", "auth", "print-access-token"], text=True
        ).strip()

        # Now use the token in the docker login command
        docker_login_cmd = f'docker login -u oauth2accesstoken  --password "{token}" https://us-west1-docker.pkg.dev'
        commands = [
            f"{docker_login_cmd}",
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
        target_branch = os.getenv("TARGET_BRANCH", "main")
        print(f"Target branch: {target_branch}")
        git_docker_operation = GitDockerOperation(target_branch=target_branch)
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

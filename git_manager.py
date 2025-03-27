import subprocess
import logging
import sys


class GitManager:
    def __init__(self, target_branch):
        self.target_branch = target_branch
        self.setup_logger()

    def setup_logger(self):
        logging.basicConfig(
            filename="git_manager.log",
            filemode="a",
            format="%(asctime)s - %(levelname)s - %(message)s",
            level=logging.INFO,
        )
        self.logger = logging.getLogger()

    def run_command(self, command):
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True, check=True
            )
            if result.stdout:
                self.logger.info(f"✅ SUCCESS: {command}\n{result.stdout.strip()}")
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"❌ ERROR: {command} failed!\n{e.stderr.strip()}")
            sys.exit(1)  # Exit immediately on failure

    def stash_changes(self):
        """Stashes local changes to avoid losing uncommitted work."""
        self.logger.info("🔄 Stashing local changes...")
        self.run_command("git stash push -m 'Auto-stash before reset'")

    def reset_main_branch(self):
        """Resets the main branch to the latest remote version."""
        self.logger.info("🔄 Resetting repository to 'main' and cleaning up...")
        self.run_command("git checkout main")
        self.run_command("git reset --hard origin/main")
        self.run_command("git clean -fd")
        self.run_command("git pull")

    def switch_branch(self):
        """Switches to the target branch and pulls the latest changes."""
        self.logger.info(f"🔄 Switching to branch '{self.target_branch}'...")
        self.run_command(f"git checkout {self.target_branch}")
        self.run_command("git pull")

    def execute(self):
        """Executes the full Git process with logging, stopping on failure."""
        self.logger.info(
            f"🚀 Starting Git operations for branch '{self.target_branch}'"
        )
        self.stash_changes()
        self.reset_main_branch()
        self.switch_branch()
        self.logger.info("✅ Git operations completed successfully!\n" + "-" * 50)


if __name__ == "__main__":
    branch_name = "jg/eda/save-end-points-results"
    git_manager = GitManager(branch_name)
    git_manager.execute()

import sys
import time
import os
from docker_startup_checker import DockerStartupMonitor
from git_docker_operation import GitDockerOperation
from docker_log_streamer import DockerLogStreamer
import subprocess
from lib.gcp import docker_gcloud_login
from lib.utils import delete_results, get_env_var, get_build_url, get_outdir
from lib.kpi import get_kpi_cmd


if __name__ == "__main__":
    current_working_dir = os.getcwd()
    print("Script started.", flush=True)
    print(f"Current working directory: {current_working_dir}", flush=True)

    docker_gcloud_login()
    delete_results()

    target_branch = get_env_var("TARGET_BRANCH", "main")

    outdir = get_outdir(current_working_dir, target_branch)
    build_url, ws_url = get_build_url(outdir)

    if not os.path.exists(outdir):
        os.makedirs(outdir, exist_ok=True)
        print(f"INFO: Created output directory: {outdir}", flush=True)

    try:
        monitor = DockerStartupMonitor(outdir=outdir)
        git_docker_operation = GitDockerOperation(
            outdir=outdir, target_branch=target_branch
        )
        docker_log_streamer = DockerLogStreamer(
            container_name="server-server-1", outdir=outdir, start_time=None
        )
        docker_log_streamer.start()
        print("INFO: Starting monitoring docker logs and git operations", flush=True)
        monitor.start_monitoring()
        print("INFO: Starting git operations and docker reset", flush=True)

        print(
            f"""INFO: Check logs for details: {ws_url}git_docker.log, {ws_url}docker_startup_monitor.log""",
            flush=True,
        )

        git_docker_operation.git_wrapper()
        git_docker_operation.hard_reset_docker()
        print("INFO: Git operations and docker reset completed", flush=True)
        print(
            "INFO: Waiting for 10 minutes before checking for server startup detection",
            flush=True,
        )
        for i in range(1, 21):
            time.sleep(30)
            if monitor.startup_detected:
                print(f"INFO: Startup detected after {i * 30} seconds", flush=True)
                break
            else:
                print(
                    f"INFO: {i * 30} seconds elapsed and startup not detected.",
                    flush=True,
                )

        if not monitor.startup_detected:
            print(
                f"ERROR: {i * 30} seconds elapsed and startup not detected. Exiting",
                flush=True,
            )
            sys.exit(1)

        kpi_log_file = os.path.join(outdir, "unit_test_kpi_run.log")
        print("INFO: Starting KPI run: ", flush=True)

        project_root, cmd = get_kpi_cmd(
            outdir, get_env_var("DESIGN_SET", "dev_v3_mini")
        )
        # Open log file for writing
        with open(kpi_log_file, "w") as log:
            # Run the command and capture stdout and stderr
            process = subprocess.run(
                cmd, stdout=log, stderr=log, cwd=project_root, check=True
            )

        print(f"Logs captured in {kpi_log_file}", flush=True)

    except Exception as e:
        print(f"Error starting Docker monitor: {e}", flush=True)
        docker_log_streamer.stop()

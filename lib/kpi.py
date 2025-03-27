import os
from pathlib import Path


def prepare_kpi_env(design_set: str = "dev_v3_mini"):
    # Define paths
    project_root = Path("/home/javad/dev/chipstack-ai")
    kpi_path = project_root / "kpi"
    # python_path = project_root / "venv/bin/python"
    python_path = "/home/javad/.pyenv/shims/python"
    unit_test_kpi_run_path = kpi_path / "chipstack_kpi/app/unit_test_kpi_run.py"
    design_file = kpi_path / f"chipstack_kpi/configs/{design_set}.yaml"

    # Set environment variables
    os.environ["PYTHONPATH"] = os.pathsep.join(
        [
            str(project_root / "common"),
            str(project_root / "client"),
            str(kpi_path),
            os.environ.get("PYTHONPATH", ""),
        ]
    )
    return python_path, project_root, unit_test_kpi_run_path, design_file


def get_kpi_cmd(outdir: str, design_set: str = "dev_v3_mini") -> list:
    python_path, project_root, unit_test_kpi_run_path, design_file = prepare_kpi_env(
        design_set
    )

    cmd = [
        str(python_path),
        str(unit_test_kpi_run_path),
        "--design_file",
        str(design_file),
        "--server_url",
        "http://localhost:8000/",
        "--eda_url",
        "https://eda.chipstack.ai/",
        "--llm_flow",
        "default",
        "--syntax_check_provider",
        "verific",
        "--output_dir",
        f"{outdir}/outdir_kpi",
        "--enable_project_support",
        "true",
        "--use_primitives",
        "false",
        "--iterate_simulation_results",
        "false",
        "--num_random_restarts",
        "0",
        "--run_type",
        "Simulation",
    ]

    return project_root, cmd

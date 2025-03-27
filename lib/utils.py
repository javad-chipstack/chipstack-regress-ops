import re
import glob
import os
import shutil
import random
import hashlib
import time


def to_variable_name(text, style="snake_case"):
    text = text.replace("/", "-")
    text = re.sub(r"[^\w\s_-]", "", text)
    text = re.sub(r"[\s-]+", "_", text)
    if re.match(r"^\d", text):
        text = "_" + text
    if style == "snake_case":
        return text.lower()
    elif style == "camelCase":
        words = text.split("_")
        return words[0].lower() + "".join(word.capitalize() for word in words[1:])
    return text


def delete_results():
    log_files = glob.glob("*.log")
    if not log_files:
        print("No log files found.", flush=True)
    else:
        for log_file in log_files:
            print(f"Removing log file: {log_file}", flush=True)
            os.remove(log_file)

    results = glob.glob("results*/")
    if not results:
        print("No results directory found.", flush=True)
    else:
        for result in results:
            print("Removing results directory.", flush=True)
            shutil.rmtree(result)
            os.rmdir(result)

    outdirs = glob.glob("outdir*/")
    if not outdirs:
        print("No outdir directories found.", flush=True)
    else:
        for outdir in outdirs:
            print("Removing outdir directory.", flush=True)
            shutil.rmtree(outdir)


def get_env_var(env_var_name: str, default_value: str | None = None) -> str:
    if default_value:
        return os.getenv(env_var_name, default_value)
    return os.getenv(env_var_name)


def get_build_url(outdir: str) -> str:
    outdir_leaf = os.path.basename(outdir)
    build_url = get_env_var("BUILD_URL", "")
    if build_url:
        print(f"Build URL: {build_url}", flush=True)
        build_url = build_url.strip() + f"/ws/{outdir_leaf}/"

    job_url = get_env_var("JOB_URL", "")
    ws_url = ""
    if job_url:
        print(f"Job URL: {job_url}", flush=True)
        ws_url = job_url.strip() + f"/ws/{outdir_leaf}/"

    return build_url, ws_url


def generate_random_string(length=8):
    timestamp = str(time.time())
    random_seed = random.randint(1, 100000)
    entropy = timestamp + str(random_seed)
    hash_obj = hashlib.md5(entropy.encode())
    hash_hex = hash_obj.hexdigest()
    return hash_hex[:length]


def get_outdir(current_working_dir: str, target_branch: str) -> str:
    return os.path.join(
        current_working_dir,
        "outdir_" + to_variable_name(target_branch) + "_" + generate_random_string(),
    )

import sys
import subprocess


def docker_gcloud_login():
    try:
        # Get access token
        # access_token = subprocess.check_output(
        #     ["gcloud", "auth", "print-access-token"], text=True
        # ).strip()

        # Construct the Docker registry URL
        # registry_url = "https://us-west1-docker.pkg.dev"

        # Run Docker login
        result = subprocess.run(
            [
                "gcloud",
                "auth",
                "activate-service-account",
                "--key-file=/home/javad/dev/chipstack-regress-ops/keys/service-account-key-kpi.json",
            ],
            text=True,
            capture_output=True,
        )

        # Check for successful login
        if result.returncode == 0:
            print("Docker login successful.")
        else:
            print("Docker login failed:", result.stderr)
            sys.exit(-1)

    except subprocess.CalledProcessError as e:
        print("Error executing command:", e)
        sys.exit(-1)


# Example usage
if __name__ == "__main__":
    docker_gcloud_login()

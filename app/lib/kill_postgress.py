import subprocess


def run_command(command):
    """Run a shell command and return the output."""
    try:
        result = subprocess.run(
            command, shell=True, check=True, capture_output=True, text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {command}\n{e.stderr}")
        return None


def remove_postgres_containers():
    """Remove all running and stopped PostgreSQL containers."""
    containers = run_command('docker ps -aq --filter "ancestor=postgres"')
    if containers:
        run_command(f"docker rm -f {containers}")
        print("Removed PostgreSQL containers.")


def remove_postgres_images():
    """Remove all PostgreSQL images."""
    images = run_command("docker images -q postgres")
    if images:
        run_command(f"docker rmi -f {images}")
        print("Removed PostgreSQL images.")


def remove_postgres_volumes():
    """Remove all PostgreSQL volumes."""
    volumes = run_command("docker volume ls -q | grep postgres")
    if volumes:
        run_command(f"docker volume rm {volumes}")
        print("Removed PostgreSQL volumes.")
    run_command("docker volume prune -f")
    print("Pruned unused volumes.")


def remove_postgres_networks():
    """Remove all PostgreSQL networks."""
    networks = run_command("docker network ls -q --filter name=postgres")
    if networks:
        run_command(f"docker network rm {networks}")
        print("Removed PostgreSQL networks.")


def main():
    print("Starting PostgreSQL cleanup...")
    remove_postgres_containers()
    remove_postgres_images()
    remove_postgres_volumes()
    remove_postgres_networks()
    print("PostgreSQL cleanup completed.")


if __name__ == "__main__":
    main()

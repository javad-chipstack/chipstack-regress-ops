import subprocess

def get_mongo_container_id():
    """Gets the container ID of the MongoDB container."""
    result = subprocess.run(["docker", "ps", "--filter", "name=server-mongodb-1", "--format", "{{.ID}}"], 
                            capture_output=True, text=True)
    container_id = result.stdout.strip()
    if not container_id:
        raise Exception("MongoDB container not found. Make sure it's running.")
    return container_id

def enter_mongo_shell(container_id):
    """Enters the MongoDB shell inside the container, authenticates, inserts a user, and lists users."""
    commands = (
        "mongosh --eval \""
        "use admin; "
        "db.auth('chipstackDBUser', 'chipstackDBPassword1!!'); "
        "use chipstackDB; "
        # "db.users.insertOne({licenseKey: '27de45f8-bef6-49f2-a275-bd7b824cda94', email: 'user@chipstack.ai', name: 'user', enabled: true}); "
        "printjson(db.users.find().toArray());"
        "\""
    )
    subprocess.run(["docker", "exec", "-it", container_id, "sh", "-c", commands], check=True)

def main():
    try:
        container_id = get_mongo_container_id()
        print(f"MongoDB container ID: {container_id}")
        enter_mongo_shell(container_id)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()

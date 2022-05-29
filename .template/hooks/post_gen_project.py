import subprocess


def main():
    subprocess.run(["git", "init"], check=True)
    subprocess.run(["git", "add", "."], check=True)
    subprocess.run(["git", "commit", "-m", "Initial commit from template"], check=True)


if __name__ == "__main__":
    main()

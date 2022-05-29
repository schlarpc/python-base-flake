import subprocess


def main():
    subprocess.run(["git", "init"], check=True)


if __name__ == "__main__":
    main()

import subprocess

try:
    # Run git log and write to scratch file
    res1 = subprocess.run(["git", "log", "-n", "20", "--oneline"], capture_output=True, text=True)
    with open("/home/aditya/clones/Card/scratch/git_log.txt", "w") as f:
        f.write("=== GIT LOG ===\n")
        f.write(res1.stdout)
        f.write(res1.stderr)

    # Run git branch and write to scratch file
    res2 = subprocess.run(["git", "branch", "-a"], capture_output=True, text=True)
    with open("/home/aditya/clones/Card/scratch/git_branches.txt", "w") as f:
        f.write("=== GIT BRANCHES ===\n")
        f.write(res2.stdout)
        f.write(res2.stderr)

    print("Success")
except Exception as e:
    print("Error:", e)

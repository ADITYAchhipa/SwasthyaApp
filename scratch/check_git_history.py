import subprocess

def run_git():
    output = []
    try:
        # Get last 15 commits affecting onboarding_screen.dart
        result = subprocess.run(
            ['git', 'log', '-n', '15', '--oneline', '--', 'lib/screens/onboarding_screen.dart'],
            cwd='/home/aditya/clones/Card',
            capture_output=True,
            text=True
        )
        output.append("STDOUT:")
        output.append(result.stdout)
        output.append("STDERR:")
        output.append(result.stderr)
        
        # Also let's run git diff to see if there are any uncommitted changes
        diff_res = subprocess.run(
            ['git', 'diff', 'lib/screens/onboarding_screen.dart'],
            cwd='/home/aditya/clones/Card',
            capture_output=True,
            text=True
        )
        output.append("\nDIFF:")
        output.append(diff_res.stdout)
    except Exception as e:
        output.append(f"Error running git: {e}")
        
    with open('/home/aditya/clones/Card/scratch/git_output.txt', 'w') as f:
        f.write('\n'.join(output))

if __name__ == '__main__':
    run_git()

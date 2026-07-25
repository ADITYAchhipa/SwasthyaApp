file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Verify block 1
block1_start_idx = -1
for idx, line in enumerate(lines):
    if '// ABHA ID Block' in line:
        block1_start_idx = idx - 1 # const SizedBox(height: 6),
        break

block1_end_idx = -1
if block1_start_idx != -1:
    # Find Container close after 'ABHA Linked'
    for idx in range(block1_start_idx, len(lines)):
        if 'ABHA Linked' in lines[idx]:
            # find first line that is exactly "                                  )," or similar
            # let's find the closing container line
            for end_idx in range(idx, len(lines)):
                if lines[end_idx].strip() == '),' and len(lines[end_idx]) - len(lines[end_idx].lstrip()) == 34:
                    block1_end_idx = end_idx
                    break
            break

# Verify block 2
block2_start_idx = -1
for idx, line in enumerate(lines):
    if '// Section 5: ABHA ID Status' in line:
        block2_start_idx = idx
        break

block2_end_idx = -1
if block2_start_idx != -1:
    # Find next SizedBox(height: 24) or SlideY line
    for idx in range(block2_start_idx, len(lines)):
        if '.slideY(begin: 0.05, end: 0, duration: 400.ms),' in lines[idx]:
            # the next line should be const SizedBox(height: 24),
            if 'const SizedBox(height: 24),' in lines[idx+1]:
                block2_end_idx = idx + 1
                break

print(f"Block 1: start={block1_start_idx}, end={block1_end_idx}")
if block1_start_idx != -1 and block1_end_idx != -1:
    print("Start line:", repr(lines[block1_start_idx]))
    print("End line:", repr(lines[block1_end_idx]))

print(f"Block 2: start={block2_start_idx}, end={block2_end_idx}")
if block2_start_idx != -1 and block2_end_idx != -1:
    print("Start line:", repr(lines[block2_start_idx]))
    print("End line:", repr(lines[block2_end_idx]))

# Do the deletion from back to front to preserve indices
if block1_start_idx != -1 and block1_end_idx != -1 and block2_start_idx != -1 and block2_end_idx != -1:
    del lines[block2_start_idx : block2_end_idx + 1]
    del lines[block1_start_idx : block1_end_idx + 1]
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print("Deletion done successfully!")
else:
    print("Error: Could not locate blocks precisely.")

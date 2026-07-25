def balance_brackets(text, start_pos):
    paren_count = 0
    bracket_count = 0
    brace_count = 0
    pos = start_pos
    started = False
    while pos < len(text):
        char = text[pos]
        if char == '(':
            paren_count += 1
            started = True
        elif char == ')':
            paren_count -= 1
            started = True
        elif char == '[':
            bracket_count += 1
            started = True
        elif char == ']':
            bracket_count -= 1
            started = True
        elif char == '{':
            brace_count += 1
            started = True
        elif char == '}':
            brace_count -= 1
            started = True
        
        if started and paren_count == 0 and bracket_count == 0 and brace_count == 0:
            return pos + 1
        pos += 1
    return -1

file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Find '// ABHA ID Block'
start_block_idx = content.find('// ABHA ID Block')
if start_block_idx != -1:
    # Find the SizedBox line right before it
    before_idx = content.rfind('const SizedBox(height: 6),', 0, start_block_idx)
    if before_idx == -1:
        before_idx = start_block_idx
        
    # Find the first 'Wrap(' after start_block_idx
    wrap_idx = content.find('Wrap(', start_block_idx)
    if wrap_idx != -1:
        # Get end of Wrap(
        end_wrap = balance_brackets(content, wrap_idx)
        if end_wrap != -1:
            # Now find '// ABHA Linked Badge' after end_wrap
            badge_idx = content.find('// ABHA Linked Badge', end_wrap)
            if badge_idx != -1:
                # Find the Container( after badge_idx
                container_idx = content.find('Container(', badge_idx)
                if container_idx != -1:
                    end_container = balance_brackets(content, container_idx)
                    if end_container != -1:
                        # We want to remove everything from before_idx up to end_container
                        # Let's clean up trailing comma if present
                        actual_end = end_container
                        while actual_end < len(content) and content[actual_end] in [',', ' ', '\n', '\r']:
                            actual_end += 1
                        
                        print(f"Removing ABHA info block: {before_idx} to {actual_end}")
                        content = content[:before_idx] + content[actual_end:]
                    else:
                        print("Failed to find end of ABHA Linked container")
                else:
                    print("Failed to find ABHA Linked container start")
            else:
                print("Failed to find '// ABHA Linked Badge'")
        else:
            print("Failed to find end of Wrap")
    else:
        print("Failed to find 'Wrap('")
else:
    print("Could not find '// ABHA ID Block'")

# 2. Find '// Section 5: ABHA ID Status'
start_sec5 = content.find('// Section 5: ABHA ID Status')
if start_sec5 != -1:
    # Find first '_buildAccordionTile(' after start_sec5
    tile_idx = content.find('_buildAccordionTile(', start_sec5)
    if tile_idx != -1:
        end_tile = balance_brackets(content, tile_idx)
        if end_tile != -1:
            # The tile might have a trailing .animate() chain.
            # Let's consume up to the next comma or SizedBox.
            actual_end = end_tile
            # Look for the animation chain and SizedBox.
            # It ends with: .animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
            # followed by: const SizedBox(height: 12),
            
            # Let's check if there is an .animate() after end_tile
            next_chars = content[end_tile:end_tile+100]
            if '.animate()' in next_chars:
                # Find the next comma after .animate()
                comma_idx = content.find(',', end_tile)
                if comma_idx != -1:
                    actual_end = comma_idx + 1
            
            # Now let's see if the next line is a SizedBox
            # e.g. const SizedBox(height: 12),
            sib_idx = content.find('const SizedBox(height: 12),', actual_end)
            if sib_idx != -1 and (sib_idx - actual_end) < 20:
                actual_end = sib_idx + len('const SizedBox(height: 12),')
                
            # Clean trailing whitespace/newlines
            while actual_end < len(content) and content[actual_end] in [' ', '\n', '\r']:
                actual_end += 1
            
            print(f"Removing Section 5: {start_sec5} to {actual_end}")
            content = content[:start_sec5] + content[actual_end:]
        else:
            print("Failed to find end of _buildAccordionTile")
    else:
        print("Failed to find '_buildAccordionTile'")
else:
    print("Could not find '// Section 5: ABHA ID Status'")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done successfully!")

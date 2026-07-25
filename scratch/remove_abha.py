import re

file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove ABHA ID Block & ABHA Linked Badge under name
# We match from the SizedBox before it down to the end of the ABHA Linked badge Container.
# Let's inspect the code between:
# const SizedBox(height: 6),
# and the closing of the ABHA Linked badge Container
pattern_abha_info = r'\s*const SizedBox\(height: 6\),\s*// ABHA ID Block[\s\S]+?// ABHA Linked Badge[\s\S]+?\}\s*,\s*\}\s*,\s*\),\s*\),\s*,'
# Let's check if we can match it more robustly:
# We know the badge ends with:
#                                               ),
#                                             ],
#                                           ),
#                                         ),

# Let's find index of '// ABHA ID Block'
start_idx = content.find('// ABHA ID Block')
if start_idx != -1:
    # Find the SizedBox(height: 6) right before it
    before_idx = content.rfind('const SizedBox(height: 6),', 0, start_idx)
    # Find the end of the ABHA Linked badge Container
    # The badge container has text 'ABHA Linked'
    badge_idx = content.find("'ABHA Linked'", start_idx)
    # Find the closing parenthesis of Container
    # It will be followed by a comma, then some closing widgets.
    # Let's find the closing structures of:
    # Row(children: [Icon, SizedBox, Text(ABHA Linked)]) -> ) -> ], ) -> ), ) -> ), ) -> ), )
    # Let's search for the end of that Container:
    # We can match matching brackets or find the unique pattern:
    # 'ABHA Linked', ...
    #                     ),
    #                   ],
    #                 ),
    #               ),
    end_pattern = r"'\s*ABHA Linked\s*',\s*style:[\s\S]+?\)\s*,\s*\]\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*"
    match = re.search(end_pattern, content[badge_idx:])
    if match:
        end_idx = badge_idx + match.end()
        print(f"Removing ABHA Info from {before_idx} to {end_idx}")
        # Remove from before_idx to end_idx
        content = content[:before_idx] + content[end_idx:]
    else:
        print("Could not find the end of ABHA Linked badge")
else:
    print("Could not find '// ABHA ID Block'")

# 2. Remove Section 5: ABHA ID Status
start_sec5 = content.find('// Section 5: ABHA ID Status')
if start_sec5 != -1:
    # We want to remove the whole _buildAccordionTile call.
    # It ends with:
    # ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
    # const SizedBox(height: 12),
    end_pattern_sec5 = r'\.animate\(\)\.fade\([\s\S]+?\),\s*const SizedBox\(height: 12\),'
    match_sec5 = re.search(end_pattern_sec5, content[start_sec5:])
    if match_sec5:
        end_sec5 = start_sec5 + match_sec5.end()
        print(f"Removing Section 5 from {start_sec5} to {end_sec5}")
        content = content[:start_sec5] + content[end_sec5:]
    else:
        print("Could not find the end of Section 5")
else:
    print("Could not find '// Section 5: ABHA ID Status'")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")

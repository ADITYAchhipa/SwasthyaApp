file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip_mode = None
skip_counter = 0

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    
    if skip_mode is None:
        # Check for first block (ABHA info under avatar)
        if '// ABHA ID Block' in stripped:
            # We want to remove the previous line (const SizedBox(height: 6),) if it was added
            if new_lines and 'SizedBox(height: 6)' in new_lines[-1]:
                new_lines.pop()
            skip_mode = 'abha_info'
            i += 1
            continue
            
        # Check for second block (Section 5 Accordion)
        elif '// Section 5: ABHA ID Status' in stripped:
            skip_mode = 'section_5'
            i += 1
            continue
            
        new_lines.append(line)
        i += 1
        
    elif skip_mode == 'abha_info':
        # Skip until we find the closing bracket of the container
        # The badge container has "ABHA Linked"
        if "'ABHA Linked'" in stripped:
            # Skip this line and the next 4 lines
            # Line 1: 'ABHA Linked',
            # Line 2: style: GoogleFonts.inter(...
            # Line 3: )
            # Line 4: ]
            # Line 5: )
            # Line 6: )
            # Line 7: )
            # Let's count how many closing parentheses we need to skip.
            # Let's just scan until we see the line with the closing Container:
            # ")," followed by ")," (which closes the Column/Row/etc.)
            # Wait, let's look at lines 300 to 315 in the original file:
            # 300:                                                 'ABHA Linked',
            # 301:                                                 style: GoogleFonts.inter(
            # 302:                                                   color: const Color(0xFF15803D),
            # 303:                                                   fontSize: 9.5,
            # 304:                                                   fontWeight: FontWeight.w800,
            # 305:                                                 ),
            # 306:                                               ),
            # 307:                                             ],
            # 308:                                           ),
            # 309:                                         ),
            # Wait, after this, we have:
            # 310:                                       ],
            # 311:                                     ),
            # 312:                                   ),
            # 313:                                 ],
            # 314:                               ),
            # 315:                               const SizedBox(height: 16),
            # Let's check! The Wrap of ABHA ID block has been closed already.
            # So the Container ends at line 309: ")," (which is the closing of Container).
            # The next lines are:
            # 310:                                       ], (closing children of Column/Row under name)
            # We want to KEEP lines 310 onwards.
            # So we skip until line 309. Line 309 is the closing of Container.
            # Let's just find the closing bracket of the Container by balancing brackets for the Container.
            # Container starts at line 287.
            # Let's just skip the specific number of lines!
            # From 'ABHA Linked' line (line 300 in original, index relative to 'ABHA Linked'):
            # index 0: 'ABHA Linked',
            # index 1: style: ...
            # index 2: color: ...
            # index 3: fontSize: ...
            # index 4: fontWeight: ...
            # index 5: ),
            # index 6: ),
            # index 7: ],
            # index 8: ),
            # index 9: ),
            # So we can skip 10 lines from 'ABHA Linked'!
            # Let's confirm by checking if the next line after 10 lines is indeed '],'.
            skip_counter = 10
            skip_mode = 'abha_info_skip_count'
        i += 1
        
    elif skip_mode == 'abha_info_skip_count':
        skip_counter -= 1
        if skip_counter == 0:
            skip_mode = None
        i += 1
        
    elif skip_mode == 'section_5':
        # Skip until we find ".slideY" and "SizedBox(height: 12)"
        # The line containing SizedBox(height: 12) is the last line we want to skip.
        if 'SizedBox(height: 12)' in stripped:
            skip_mode = None
        i += 1

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Done successfully!")

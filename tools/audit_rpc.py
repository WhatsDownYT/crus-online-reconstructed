




from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
for path in sorted(root.rglob('*.gd')):
    if 'tests' in path.parts:
        continue
    source = path.read_text(encoding='utf-8-sig')
    registrations = set(re.findall(r'\["([^"]+)",\s*(?:NetworkBridge|SteamNetwork)\.PERMISSION\.', source))
    properties = set(re.findall(r'register_rset\(self,\s*"([^"]+)"', source))
    for line_number, line in enumerate(source.splitlines(), 1):
        if line.lstrip().startswith('#'):
            continue
        match = re.search(r'n_(rpc(?:_unreliable)?|rset(?:_unreliable)?)\(self,\s*"([^"]+)"', line)
        if match:
            kind, member = match.groups()
            known = properties if kind.startswith('rset') else registrations
            if member not in known:
                print(f'{path.relative_to(root)}:{line_number}: review unregistered {kind} {member}')

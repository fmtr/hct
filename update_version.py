import re
import sys
from pathlib import Path

PATH_ROOT = Path(__file__).parent.absolute()
ENCODING = 'UTF-8'
PATTERN_VERSION = r'(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<pre>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?(?:\+(?P<build>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?'
STEMS_MASKS = {
    'module/hct_version.be': r"var\s+VERSION\s*=\s*'({})'",
    # 'README.md': r"fmtr/hct/v({})",
}
VERSION = sys.argv[1]


def replacer(match):
    text_new = match.group(0).replace(match.group(1), VERSION)
    return text_new


if __name__ == '__main__':
    for stem, mask in STEMS_MASKS.items():
        path = PATH_ROOT / stem
        text_old = path.read_text(encoding=ENCODING)
        pattern = mask.format(PATTERN_VERSION)
        replacement = pattern.format(VERSION)
        text = re.sub(pattern, replacer, text_old)
        path.write_text(text, encoding=ENCODING)
        print(f'Wrote versions to file: "{path}"')

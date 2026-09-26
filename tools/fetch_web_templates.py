"""Install the official Godot 4.5 Web templates inside this project."""
import argparse
import subprocess
import tempfile
import zipfile
from pathlib import Path

URL = 'https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_export_templates.tpz'

def install(archive):
    dest = Path(__file__).resolve().parent.parent / '.tools' / 'web-templates'
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for name in ['web_nothreads_release.zip', 'web_nothreads_debug.zip']:
            data = bundle.read('templates/' + name)
            (dest / name).write_bytes(data)
            print(f'Installed {name}: {len(data)} bytes', flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Existing official .tpz archive')
    args = parser.parse_args()
    if args.archive:
        install(args.archive)
    else:
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'templates.tpz'
            subprocess.run(['curl', '-fL', '--retry', '3', '-o', str(archive), URL], check=True)
            install(archive)

if __name__ == '__main__':
    main()

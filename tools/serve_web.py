"""Serve FORMA Web with its automatic multiplayer room server by default."""
import argparse
import functools
import http.server
import shutil
import signal
import subprocess
import threading
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8787)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--multiplayer', action='store_true', default=True)
    parser.add_argument('--web-only', action='store_false', dest='multiplayer',
                        help='Serve only Web files when using a separate room server')
    parser.add_argument('--no-open', action='store_true')
    args = parser.parse_args()
    def stop_server(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop_server)
    if not (ROOT / 'web/index.html').exists():
        parser.error('Execute tools/export_web.sh para gerar a versão Web.')
    server_process = None
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'web'))
    with http.server.ThreadingHTTPServer((args.bind, args.port), handler) as server:
        if args.multiplayer:
            engine = ROOT / '.tools/Godot.app/Contents/MacOS/Godot'
            executable = str(engine) if engine.exists() else shutil.which('godot')
            if not executable:
                parser.error('Instale Godot 4.5 para iniciar o servidor multiplayer.')
            server_process = subprocess.Popen([executable, '--headless', '--path', str(ROOT), '--', '--server'])
        url = f'http://127.0.0.1:{args.port}'
        print(f'FORMA: {url}\nCtrl+C para encerrar.', flush=True)
        if not args.no_open:
            threading.Timer(0.7, lambda: webbrowser.open(url)).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            if server_process:
                server_process.terminate()
                server_process.wait(timeout=10)

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Run a local build/check in the shared per-user resource queue (macOS/Linux)."""
import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys


def main():
    command = sys.argv[1:]
    if command[:1] == ['--']:
        command = command[1:]
    if not command or command == ['--help']:
        print('Usage: python3 tool/resource_queue.py <command> [arguments...]')
        return 0 if command else 2

    if os.environ.get('CODEX_RESOURCE_QUEUE_ACTIVE'):
        print('Resource queue: already queued; invoke this command without a second wrapper.',
              file=sys.stderr)
        return 2

    # Все worktree используют один файл. Не удалять: это создаст вторую очередь.
    lock_path = Path('/tmp') / f'codex-heavy-{os.getuid()}.lock'
    with lock_path.open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Resource queue: waiting for the other build/check to finish.',
                  file=sys.stderr, flush=True)
            fcntl.flock(lock, fcntl.LOCK_EX)
        print(f'Resource queue: acquired (PID {os.getpid()}).',
              file=sys.stderr, flush=True)
        try:
            child = subprocess.Popen(
                command, start_new_session=True,
                env={**os.environ, 'CODEX_RESOURCE_QUEUE_ACTIVE': '1'})
        except OSError as error:
            print(f'Resource queue: {error}', file=sys.stderr)
            return 127

        def forward(signum, _frame):
            # Останавливаем только группу команды, запущенной этой обёрткой.
            try:
                os.killpg(child.pid, signum)
            except ProcessLookupError:
                pass

        for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(signum, forward)
        try:
            code = child.wait()
        finally:
            forward(signal.SIGTERM, None)
        return code if code >= 0 else 128 - code


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)

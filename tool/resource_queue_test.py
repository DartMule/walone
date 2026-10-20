import os
from pathlib import Path
import signal
import tempfile
import unittest
from unittest.mock import Mock, patch

from tool import resource_queue as queue


class ResourceQueueTest(unittest.TestCase):
    def run_queue(self, running=False):
        child = Mock(pid=12345)
        child.poll.return_value = None if running else 0
        child.wait.return_value = 0
        handlers = {}
        if running:
            child.wait.side_effect = lambda: handlers[signal.SIGTERM](signal.SIGTERM, None)
        with tempfile.TemporaryDirectory() as temporary, \
             patch.object(queue, 'Path', return_value=Path(temporary)), \
             patch.object(queue.sys, 'argv', ['resource_queue', 'command']), \
             patch.dict(os.environ, {'CODEX_RESOURCE_QUEUE_ACTIVE': ''}), \
             patch.object(queue.subprocess, 'Popen', return_value=child), \
             patch.object(queue.signal, 'signal', side_effect=lambda signum, handler: handlers.update({signum: handler})), \
             patch.object(queue.os, 'killpg', side_effect=PermissionError('Operation not permitted')):
            return queue.main()

    def test_completed_command_keeps_success_if_process_group_cleanup_is_denied(self):
        self.assertEqual(self.run_queue(), 0)

    def test_denied_signal_for_a_running_command_is_not_silenced(self):
        with self.assertRaises(PermissionError):
            self.run_queue(running=True)


if __name__ == '__main__':
    unittest.main()

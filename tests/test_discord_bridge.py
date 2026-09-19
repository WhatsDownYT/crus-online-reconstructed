import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import queue
import struct
import subprocess
import tempfile
import threading
import time

api = ctypes.WinDLL('kernel32', use_last_error=True)
api.CreateNamedPipeW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
api.CreateNamedPipeW.restype = wintypes.HANDLE
api.ConnectNamedPipe.argtypes = [wintypes.HANDLE, ctypes.c_void_p]
api.ReadFile.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
api.WriteFile.argtypes = api.ReadFile.argtypes
api.CloseHandle.argtypes = [wintypes.HANDLE]


class Pipe:
    def __init__(self, name):
        self.handle = api.CreateNamedPipeW('\\\\.\\pipe\\' + name, 3, 0, 1, 65536, 65536, 0, None)
        if self.handle == wintypes.HANDLE(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())

    def accept(self):
        if not api.ConnectNamedPipe(self.handle, None) and ctypes.get_last_error() != 535:
            raise ctypes.WinError(ctypes.get_last_error())

    def read(self, count):
        data = b''
        while len(data) < count:
            buffer = ctypes.create_string_buffer(count - len(data))
            received = wintypes.DWORD()
            if not api.ReadFile(self.handle, buffer, len(buffer), ctypes.byref(received), None) or not received.value:
                raise EOFError('Pipe closed')
            data += buffer.raw[:received.value]
        return data

    def frame(self):
        opcode, length = struct.unpack('<II', self.read(8))
        assert length <= 65536
        return opcode, json.loads(self.read(length))

    def send(self, opcode, payload, split=False):
        body = json.dumps(payload).encode()
        frame = struct.pack('<II', opcode, len(body)) + body
        parts = [frame[:3], frame[3:8], frame[8:]] if split else [frame]
        for part in parts:
            count = wintypes.DWORD()
            if not api.WriteFile(self.handle, part, len(part), ctypes.byref(count), None):
                raise ctypes.WinError(ctypes.get_last_error())
            if split:
                time.sleep(0.02)

    def close(self):
        api.CloseHandle(self.handle)


def run():
    root = Path(__file__).resolve().parents[1]
    prefix = 'crus-test-' + str(os.getpid()) + '-'
    outcomes = queue.Queue()
    with tempfile.TemporaryDirectory(prefix='crus-discord-test-') as temporary:
        state = Path(temporary) / 'presence.json'
        state.write_text(json.dumps({'details': 'Playing Singleplayer'}))
        server = Pipe(prefix + '0')

        def serve():
            current = server
            try:
                current.accept()
                opcode, body = current.frame()
                assert opcode == 0 and body == {'v': 1, 'client_id': '1550836628509954048'}
                current.send(1, {'cmd': 'DISPATCH', 'evt': 'READY'}, split=True)
                assert current.frame()[1]['evt'] == 'ACTIVITY_JOIN'
                opcode, body = current.frame()
                assert opcode == 1 and body['cmd'] == 'SET_ACTIVITY'
                assert body['args']['pid'] == os.getpid()
                assert body['args']['activity']['details'] == 'Playing Singleplayer'
                current.send(1, {'cmd': 'DISPATCH', 'evt': 'ACTIVITY_JOIN', 'data': {'secret': 'crus1:109775241234567890:76561198012345678'}}, split=True)
                joined = Path(str(state) + '.join')
                deadline = time.monotonic() + 3
                while not joined.exists() and time.monotonic() < deadline:
                    time.sleep(0.05)
                assert joined.read_text() == 'crus1:109775241234567890:76561198012345678'
                joined.unlink()
                for invalid in ['crus1:123:0', 'crus1:123:456;calc', 'other:123:456', 'crus1:9223372036854775808:456']:
                    current.send(1, {'cmd': 'DISPATCH', 'evt': 'ACTIVITY_JOIN', 'data': {'secret': invalid}})
                current.send(3, {'ping': 'test'}, split=True)
                opcode, body = current.frame()
                assert opcode == 4 and body == {'ping': 'test'}
                assert not joined.exists()
                changed = {'details': 'Playing Online', 'party': {'size': [2, 16]}}
                state.write_text(json.dumps(changed))
                opcode, body = current.frame()
                assert body['args']['activity'] == changed
                current.close()
                current = Pipe(prefix + '0')
                current.accept()
                assert current.frame()[0] == 0
                current.send(1, {'cmd': 'DISPATCH', 'evt': 'READY'})
                assert current.frame()[1]['evt'] == 'ACTIVITY_JOIN'
                assert current.frame()[1]['args']['activity'] == changed
                current.send(1, {'cmd': 'SET_ACTIVITY', 'evt': None, 'data': {}})
                state.unlink()
                assert current.frame()[1]['args']['activity'] is None
                outcomes.put(None)
            except BaseException as error:
                outcomes.put(error)
            finally:
                current.close()

        threading.Thread(target=serve, daemon=True).start()
        helper = subprocess.Popen([str(root / 'discord/CruSDiscord.exe'), str(os.getpid()), str(state), '1550836628509954048', prefix], creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            result = outcomes.get(timeout=25)
            if result:
                raise result
            assert helper.wait(timeout=5) == 0
            print('DISCORD_BRIDGE_TEST handshake, fragmented frames, ping, updates, reconnect, clearing: PASS')
        finally:
            if helper.poll() is None:
                helper.terminate()
                helper.wait()
        state.write_text('{}')
        helper = subprocess.Popen([str(root / 'discord/CruSDiscord.exe'), str(os.getpid()), str(state), '1550836628509954048', prefix + 'absent-'], creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            time.sleep(1.5)
            assert helper.poll() is None
            state.unlink()
            assert helper.wait(timeout=5) == 0
            print('DISCORD_BRIDGE_TEST Discord absent and shutdown: PASS')
        finally:
            if helper.poll() is None:
                helper.terminate()
                helper.wait()


if __name__ == '__main__':
    run()

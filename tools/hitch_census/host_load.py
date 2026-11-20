"""Read-only macOS load samples for quick census takes."""
from __future__ import annotations

import ctypes
import os
import struct
import time

SAMPLE_SECONDS = 5
EXTERNAL_CPU_LOAD_PERCENT = 100.0  # One logical core.

# Darwin <sys/proc_info.h>: proc_taskallinfo (proc_bsdinfo + proc_taskinfo).
PROC_PIDTASKALLINFO = 2
TASK_INFO = struct.Struct('=16xI28x16s32s24xQQ16xQQ64x')
# Darwin <mach/host_info.h>: user, system, idle, nice CPU ticks.
HOST_CPU_LOAD_INFO = 3
CPU_STATES = 4
NS_PER_SECOND = 1_000_000_000


class Sampler:
    def __init__(self, owner_pid, started):
        self.owner_pid = owner_pid
        self.started = started
        self.logical_cpus = os.cpu_count() or 1
        self.proc = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
        self.mach = ctypes.CDLL(None)
        self.mach.mach_host_self.restype = ctypes.c_uint
        timebase = (ctypes.c_uint * 2)()
        if self.mach.mach_timebase_info(timebase) != 0 or not timebase[1]:
            raise OSError('mach_timebase_info could not resolve CPU tick units')
        self.ns_per_tick = timebase[0] / timebase[1]
        self.previous = None

    def _processes(self):
        capacity = self.proc.proc_listallpids(None, 0)
        if capacity <= 0:
            raise OSError('proc_listallpids could not enumerate processes')
        pids = (ctypes.c_int * (capacity * 2))()
        count = self.proc.proc_listallpids(pids, ctypes.sizeof(pids))
        if not 0 < count < len(pids):
            raise OSError('proc_listallpids returned an incomplete process list')
        buffer = ctypes.create_string_buffer(TASK_INFO.size)
        processes = {}
        skipped = 0
        for pid in pids[:count]:
            if pid <= 0:
                continue
            size = self.proc.proc_pidinfo(pid, PROC_PIDTASKALLINFO, ctypes.c_uint64(0), buffer, len(buffer))
            if size != len(buffer):
                skipped += 1
                continue
            parent, comm, name, start_sec, start_usec, user, system = TASK_INFO.unpack(buffer)
            executable = (name.split(b'\0', 1)[0] or comm.split(b'\0', 1)[0]).lower()
            processes[pid] = (parent, executable.startswith(b'godot'), (pid, start_sec, start_usec), user + system)
        return processes, skipped

    def _cpu_ticks(self):
        ticks = (ctypes.c_uint * CPU_STATES)()
        count = ctypes.c_uint(CPU_STATES)
        status = self.mach.host_statistics(self.mach.mach_host_self(), HOST_CPU_LOAD_INFO, ticks, ctypes.byref(count))
        return tuple(ticks) if status == 0 and count.value == CPU_STATES else None

    def sample(self):
        now = time.monotonic()
        load = {'elapsed_seconds': round(now - self.started, 2), 'logical_cpus': self.logical_cpus}
        try:
            load['load_average'] = list(os.getloadavg())
        except OSError:
            load['load_average'] = None
        try:
            processes, skipped = self._processes()
        except OSError as error:
            load['process_sample_error'] = str(error)
            return load
        owned = {self.owner_pid}
        while True:
            children = {pid for pid, (parent, _, _, _) in processes.items() if parent in owned}
            if children <= owned:
                break
            owned.update(children)
        godot = {pid for pid, (_, is_godot, _, _) in processes.items() if is_godot}
        other = godot - owned
        load.update(other_godot_pids=sorted(other), inaccessible_processes=skipped,
                    census_godot_cpu_share_pct=None, other_godot_cpu_share_pct=None, external_cpu_share_pct=None)
        current = {identity: cpu for _, _, identity, cpu in processes.values()}
        ticks = self._cpu_ticks()
        if self.previous is not None:
            previous_time, previous_cpu, previous_ticks = self.previous
            divisor = (now - previous_time) * NS_PER_SECOND * self.logical_cpus / 100

            def share(pids):
                identities = [processes[pid][2] for pid in pids]
                deltas = [current[key] - previous_cpu[key] for key in identities if key in previous_cpu]
                return sum(max(0, delta) for delta in deltas) * self.ns_per_tick / divisor if deltas or not identities else None

            census_cpu = share(godot & owned) if godot & owned else None
            load['census_godot_cpu_share_pct'] = census_cpu
            load['other_godot_cpu_share_pct'] = share(other)
            if ticks and previous_ticks and census_cpu is not None:
                user, system, idle, nice = ((new - old) % (2**32) for new, old in zip(ticks, previous_ticks))
                busy = user + system + nice
                if busy + idle:
                    load['external_cpu_share_pct'] = max(0, 100 * busy / (busy + idle) - census_cpu)
        self.previous = now, current, ticks
        return load


def condition(samples):
    for entry in samples:
        average = entry.get('load_average')
        external = entry.get('external_cpu_share_pct')
        if (entry.get('other_godot_pids') or (average and average[0] >= entry['logical_cpus'])
                or (external is not None and external * entry['logical_cpus'] >= EXTERNAL_CPU_LOAD_PERCENT)):
            return 'under load'
    if any(entry.get('load_average') and entry.get('external_cpu_share_pct') is not None for entry in samples):
        return 'no load detected'
    return 'load unknown'

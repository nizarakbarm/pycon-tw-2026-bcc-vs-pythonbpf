# Python eBPF: BCC C-String Runtime vs Python-BPF AST AOT

PyCon Taiwan 2026. Two Python eBPF frameworks, the same `sys_enter_execve` tracepoint, two million events, three measurement passes over six programs.

The claim the talk makes: both frameworks load a BPF program into the kernel by the same path, so every per-event difference belongs to **user space**, not to the BPF program.

## Contents

```
presentation.pdf          the talk (31 slides)
img/                      figures used in the deck
experiment/
  results/                the dataset — three passes over the same six programs
    unprofiled/           pass 1 — no instrumentation; [TIMING] + [RUSAGE]
    straceT/              pass 2 — strace -f -T; full syscall traces + rankings
    perfrecord/           pass 3 — perf record; folded stacks + flamegraphs
    README.md             how to read each pass — read this first
  scripts/                the runners (rebash sweep, per-arm runner, ranker, verifier)
  with_map/               the six programs, BCC and Python-BPF
  without_map/            an earlier variant, kept for audit
  Python-BPF/             the fork's own examples, including the two limitation cases
                          (vendor of pythonbpf/Python-BPF at f2e6fba, 2026-10-09; .git removed)
  ghostlock/              the end-to-end deny demo (see the limitations)
  trigger/                the 2M fork+execve trigger
```

## Headline numbers

Recomputed from `experiment/results/unprofiled` by parsing `[TIMING] Total CPU` from each arm. 2M events, `vmnono` (hostname `nono1`), un-profiled pass:

| variant | BCC | Python-BPF | ratio |
|---|---|---|---|
| `count` | 134.57 s | 103.66 s | **1.30** |
| `A` — empty callback | 103.28 s | 84.04 s | **1.23** |
| `B` — print a constant | 111.24 s | 92.30 s | **1.21** |

Syscall counts at 2M, from `results/straceT/*.rank.txt`:

| | BCC | Python-BPF |
|---|---|---|
| `gettid` | 1,907,735 | 3 |
| total syscalls | 3,913,286 | 2,055,624 |
| calls per event | 1.96 | 1.03 |

The `A` row is the point: with the callback reduced to `pass`, BCC still spends 19.2 s more CPU. Nothing in the callback can explain that gap.

## What is in the dataset, and what is not

The raw tree is 4.4 GB. This repository keeps the **derived** artifacts and the sources, which is **127 MB**. Excluded, with the reason:

| excluded | size | why it is safe to drop |
|---|---|---|
| `*.data` (perf record binary) | 177–256 MB each, 36 files | `*.folded` is the derived form the flamegraphs and every profile share come from, and the README gives the exact `perf script \| stackcollapse-perf.pl` command to regenerate any `.data` |
| `*.T.txt` (full strace traces) | 160–368 MB each, 42 files | `*.rank.txt` is the derived summary (one row per syscall, call count and total time). The README's ranker regenerates `.rank.txt` from `.T.txt` |
| per-event stdout dumps at N=2M | 62–93 MB each | one printed line per event. Every figure in the deck comes from `[TIMING]`, `[RUSAGE]`, `[SUMMARY]` and the `rank.txt` files, all of which are here. For the two `map1_count` 2M arms, those summary lines are kept in the `.log` in place of the full dump |

Nothing you need to check a number in the talk is missing: all 36 program logs, all `.rank.txt`, all `.folded`, all `.svg`, `README.md`, the scripts, and the six programs.

## How to read the numbers

- **Quote CPU, not wall.** The trigger is a sequential `fork` → `wait` loop at about 0.7 ms per event, so wall measures the trigger and agrees between frameworks to 0.3% while CPU differs by 30% in the same pair.
- **Do not compare CPU across passes.** `--call-graph dwarf` unwinds in the target's own context and roughly doubles measured CPU, so pass 3 absolute CPU sits about 80% above pass 1. Ratios also move with the instrument: un-profiled 1.30 / 1.23 / 1.21, under `perf record` 1.21 / 1.17 / 1.08. Direction is stable; magnitude is not.
- **Rusage and `[TIMING]` are different accountings.** `[TIMING]` is `process_time()`, self only, scoped to a phase. Rusage counts self and children across the process lifetime. Do not compare them to each other.
- **Do not fire the trigger on a fixed pre-sleep.** Under `strace` or `perf record` the traced child starts after `$!`, so a fixed sleep can expire before attach; the burst is then lost with no `[LOST]` printed. The runners wait for the program to report it is polling. `results/README.md` records the two arms that failed this way.
- **Delivery is asserted per arm.** `[SUMMARY] Events in map` must equal `N+1` (the trigger's own `exec` adds one).

## Limitations the talk reports

Four, all live. Each is a Python-BPF gap, and each is a compiler or helper gap rather than a design limit. Two are visible in this tree:

- **No in-kernel deny, so enforcement is a userspace kill.** Python-BPF cannot attach a BPF-LSM program, cannot call `bpf_override_return`, and cannot call `bpf_send_signal`. The consequence is ordering: a userspace kill acts after the syscall returns, while a seccomp filter acts before it, so a kill cannot block the call that is already running. `experiment/ghostlock/` is the end-to-end demo.
- **Two sections on one register struct.** A program with two sections that both take `struct_pt_regs` loads and attaches, and prints garbage, with no error. `experiment/Python-BPF/BCC-Examples/disksnoop.py` is that shape: `kprobe/blk_mq_end_request` and `kprobe/blk_mq_start_request`, both typed `struct_pt_regs`.

The other two: no two-step kernel read, so a kernel string cannot be dereferenced; and silent codegen traps, where eight context fields in one `printk`, or five `printk` statements, compile and attach and emit zero trace output. A struct as a map-value that cannot be written through (`opt: invalid getelementptr indices`) is a fifth gap we name in the talk but do not count as its own, because it shares the translator cause with the silent traps.

## Reproducing

The triggers and the environment are described in `experiment/results/README.md`, which also carries the six program checksums recorded at packaging time and the three sweep commands.

## Links

- Python-BPF — <https://github.com/python-bpf/python-bpf>
- BCC — <https://github.com/iovisor/bcc>
- Slidev — <https://sli.dev>

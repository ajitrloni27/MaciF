# Namma MedGate

Namma MedGate is a Flutter prototype for contactless patient intake and protected transmission workflows. The app is designed to demonstrate a realistic clinical handoff experience from intake to specialist review prioritising reliability and recovery behavior.


## Current Features

| Feature | Description |
|---|---|
| **GZIP Compression** | Payload shrinks before leaving the device. |
| **Pipeline** | Raw data → binary encoding → gzip → encryption → redundancy chunks → network transmission. |
| **Delta Encoding** | Only changed fields are sent, compared against the last *successfully transmitted* record in local storage — not just the last edit. |
| **Recovery (XOR/Reed-Solomon)** | RAID 5-style parity reconstructs lost chunks. Fails honestly past its correction limit — same as QR codes failing when damage is too severe. |
| **Recovery Confidence Score** | Reflects real math, not inflated. Severe loss can mean partial or failed recovery — that's intentional, not a bug. |
| **Priority Ordering** | Vitals always transmit before images. |
| **Progressive Specialist View** | Sections unlock as data rebuilds; shows rebuilt data, changed fields, checksums, and transmission proof. |
| **Store-and-Forward** | Failed sends retry automatically. |
| **Urgent Case Mode** | Speeds up fallback trigger; lets a tiny thumbnail through even in fallback. |
| **Network Simulator** | Adjustable loss/bandwidth profiles with live feedback on packet loss, recovery, delivery time, and compression size. |
| **Image Recovery** | Same erasure-coding pipeline applied to image tiles — specialist console shows corrupted-vs-recovered images side by side, with real stats. |
| **Clinical Alerts** | Glass-style banners/toasts tied to real events — rebuild failure, degraded channel, fallback activation, NFC issues, implausible vitals. |

## Tech Stack

| Layer | Tools Used |
|---|---|
| **App Framework** | Flutter, Dart |
| **State Management** | Riverpod |
| **Navigation** | Go Router |
| **NFC** | NFC Manager |
| **Local Storage** | sqflite |
| **Animation** | Flutter Animate |
| **Chunking Acceleration** | Optional Rust (native FFI) |

## Why Open-Source Building Blocks

| Package | Purpose |
|---|---|
| `archive` | GZIP/DEFLATE compression |
| `crypto` | Field-level hashing |
| `encrypt` | Payload encryption |
| `flutter_image_compress` | Image compression |

Real, proven algorithms — not reinvented ones.

## Rust

| Aspect | Reason |
|---|---|
| **Workload** | Chunking is CPU-bound, byte-heavy work |
| **Benefit** | Faster processing, no GC overhead |
| **Fallback** | Automatically uses pure Dart if Rust isn't installed |

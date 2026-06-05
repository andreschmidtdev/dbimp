# Project 01: Buffer Pool Manager

This project was developed as part of the course *Implementation of Database Systems*.

## Overview

This project implements a basic buffer pool manager in Zig. The buffer pool manager is responsible for managing a fixed number of memory frames, loading pages from disk when required, tracking page state, and evicting pages when memory becomes full.

The implementation supports:

- Page allocation and deallocation
- Page retrieval through page identifiers (PFNs)
- Pin count tracking
- Dirty page tracking and flushing
- Disk-backed page storage
- LRU (Least Recently Used) page replacement
- Unit tests for core functionality
- Simple benchmark workloads using Zipfian access distributions

## Project Structure

```text
src/
├── buffer_manager.zig
├── page_allocator.zig
├── pfn_table.zig
├── disk_manager.zig
├── page.zig
├── benchmark.zig
└── distribution.zig
```

### Main Components

#### Buffer Manager

Coordinates page allocation, page retrieval, flushing, pin tracking, and page replacement.

#### PFN Table

Tracks the state of every page in the system, including:

- Current location (memory or disk)
- Pin count
- Dirty status
- LRU metadata

#### Page Allocator

Manages the fixed-size in-memory buffer and allocates/free frames.

#### Disk Manager

Provides persistent storage for pages using a backing file.

## Replacement Strategy

The buffer manager uses a simple LRU (Least Recently Used) replacement policy.

LRU information is maintained directly inside the PFN table using an intrusive doubly linked list based on PFN indices rather than dynamically allocated list nodes.

## Testing

The project includes unit tests covering:

- Page allocation and deallocation
- Page retrieval
- Dirty-page handling
- Pin count management
- Page flushing
- Page eviction and reload behavior
- LRU bookkeeping

## Benchmarking

A small benchmark suite is included to evaluate the behavior of the buffer manager under different memory capacities and Zipfian access distributions. The benchmark is intended primarily for functional evaluation and rough performance comparisons rather than rigorous performance analysis.

## NOtes

This project was developed within a relatively short timeframe and represents my first experience with both Zig and low-level systems programming.


As a result, the implementation intentionally focuses on the core concepts of a buffer pool manager rather than completeness or performance. The current version provides a simple single-threaded design with LRU-based page replacement, dirty-page handling, pin tracking, and disk-backed storage.


Many aspects could be extended further, such as concurrency support, asynchronous I/O, more advanced replacement policies, and additional optimizations. However, the primary goal of this project was to gain hands-on experience with the underlying mechanisms used in database systems and to implement a working end-to-end buffer manager from scratch.

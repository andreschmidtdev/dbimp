# Project 01: Buffer Pool Manager

This project is part of the course **Implementation of Database Systems**.

## Description

This project implements a buffer pool manager in Zig. The buffer pool manager is responsible for managing a fixed number of in-memory pages and coordinating access to pages stored on disk.

The implementation focuses on core buffer management functionality, including page allocation, page fetching, page replacement, dirty-page handling, and writing modified pages back to disk when necessary.

## Goals

- Manage a fixed-size pool of memory frames
- Load pages from disk into memory
- Track page usage and pin counts
- Handle dirty pages correctly
- Evict pages using a replacement strategy
- Provide tests for the main buffer pool operations

## Structure

```text
.
├── build.zig
├── build.zig.zon
├── src/
└── test/

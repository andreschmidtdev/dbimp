const Page = @import("page.zig").Page;
const page_size = @import("page.zig").page_size;
const std = @import("std");
const PageAllocator = @import("page_allocator.zig").PageAllocator;
const PFNTable = @import("pfn_table.zig").PFNTable;
const DiskManager = @import("disk_manager.zig").DiskManager;
const default_frame_count = 64;
const default_disk_page_count = 256;

pub const BufferManagerError = error {
    EvictionNotPossible,
    PageNotAllocated,
};

pub const BufferManager = struct {
    allocator : std.mem.Allocator,
    page_allocator: PageAllocator,
    pfn_table: PFNTable,
    disk_manager : DiskManager,

    pub fn init(allocator: std.mem.Allocator) !BufferManager {
        return try BufferManager.initWithSizes(
            allocator,
            default_frame_count,
            default_disk_page_count,
        );
    }
        
    pub fn initWithSizes(
        allocator: std.mem.Allocator,
        frame_count: usize,
        disk_page_count: usize,
    ) !BufferManager {
        const disk_capacity = disk_page_count * page_size;

        return .{
            .allocator = allocator,
            .page_allocator = try PageAllocator.init(frame_count, allocator),
            .pfn_table = try PFNTable.init(disk_page_count, allocator),
            .disk_manager = try DiskManager.init("test.db", disk_capacity),
        };
    }
    
    pub fn deinit(self: *BufferManager) void {
        self.disk_manager.deinit();
        self.page_allocator.deinit(self.allocator);
        self.pfn_table.deinit(self.allocator);
    }

    fn evictFirstUnpinned(self: *BufferManager) !void {
        for(self.pfn_table.pfn_entries,0..) |entry,i| {
            if(entry.state == .in_memory and entry.pin_count == 0) {
                if(entry.dirty) {
                   try self.FlushPage(i);
                }
                try self.pfn_table.markOnDisk(i);
                try self.page_allocator.freeFrame(entry.location);
                return;
            }
        }
        return BufferManagerError.EvictionNotPossible;
    }

    // Allocates a page frame. Also allocates and returns a corresponding PFN.
    pub fn AllocPageFrame(self: *BufferManager) !struct { pfn: u64, page: *Page } {

        const free_pfn: usize = try self.pfn_table.findFreePFN(); 
        if(self.page_allocator.full()) {
            try self.evictFirstUnpinned();
        }
        const frame = try self.page_allocator.allocFrame();
        const frame_index: usize = frame.frame_index;

        try self.pfn_table.markInMemory(free_pfn, frame_index);
        try self.pfn_table.incrementPinCount(free_pfn);
        try self.pfn_table.markDirty(free_pfn);

        return .{
            .pfn = @intCast(free_pfn),
            .page = frame.page,
        };
    }

    // Final free of a page frame.
    pub fn FreePageFrame(self: *BufferManager, pfn: u64) !void {
        const pfn_index: usize = @intCast(pfn);
        const entry = try self.pfn_table.getEntry(pfn_index);

        switch (entry.state) {
            .not_allocated => {
                return BufferManagerError.PageNotAllocated;
            },

            .in_memory => {
                // markNotAllocated checks pin_count == 0.
                try self.pfn_table.markNotAllocated(pfn_index);
                try self.page_allocator.freeFrame(entry.location);
            },

            .on_disk => {
                try self.pfn_table.markNotAllocated(pfn_index);
            },
        }
    }
        // Get the page of a PFN either from memory or disk.

    pub fn PFNToPage(self: *BufferManager, pfn: u64) !*Page {
        const pfn_index: usize = @intCast(pfn);

        switch (self.pfn_table.pfn_entries[pfn_index].state) {
            .not_allocated => {
                return BufferManagerError.PageNotAllocated;
            },

            .in_memory => {
                // already resident, nothing to load
            },

            .on_disk => {
                if (self.page_allocator.full()) {
                    try self.evictFirstUnpinned();
                }

                const allocated_frame = try self.page_allocator.allocFrame();

                try self.disk_manager.readPage(pfn_index, allocated_frame.page);

                try self.pfn_table.markInMemory(
                    pfn_index,
                    allocated_frame.frame_index,
                );
            },
        }

        const frame_number = try self.pfn_table.getFrameNumber(pfn_index);

        try self.pfn_table.incrementPinCount(pfn_index);

        return try self.page_allocator.getFrame(frame_number);
    }

    pub fn MarkDirty(self: *BufferManager, pfn: u64) !void {
        const pfn_index: usize = @intCast(pfn);

        try self.pfn_table.markDirty(pfn_index);
    }

    // Flush a dirty page to disk and clear its dirty bit.
    pub fn FlushPage(self: *BufferManager, pfn: u64) !void {
        const pfn_index: usize = @intCast(pfn);
        const frame_number = try self.pfn_table.getFrameNumber(pfn_index);
        const page = try self.page_allocator.getFrame(frame_number);
        try self.disk_manager.writeToPage(pfn_index,page);
        try self.pfn_table.clearDirty(pfn_index);
    }

    // Releases a page by decrementing the pin count.
    pub fn DecrementPinCount(self: *BufferManager, pfn: u64) void {
        const pfn_index: usize = @intCast(pfn);

        self.pfn_table.decrementPinCount(pfn_index) catch unreachable;
    }

    // Optional.
    pub fn PFNToPageAsync(self: *BufferManager, pfn: u64, thread_id: u64) !?*Page {
        _ = self;
        _ = pfn;
        _ = thread_id;
        @panic("TODO");
    }
};

// testing

test "Full in-memory lifecycle" {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    var bm = try BufferManager.init(allocator);
    defer bm.deinit();

    const allocated = try bm.AllocPageFrame();
    allocated.page.mem[0] = 42;
    try bm.MarkDirty(allocated.pfn);

    const pfn_index: usize = @intCast(allocated.pfn);
    var entry = try bm.pfn_table.getEntry(pfn_index);

    try std.testing.expectEqual(.in_memory, entry.state);
    try std.testing.expectEqual(true, entry.dirty);
    try std.testing.expectEqual(@as(usize, 1), entry.pin_count);

    try bm.FlushPage(allocated.pfn);
    entry = try bm.pfn_table.getEntry(pfn_index);
    try std.testing.expectEqual(false, entry.dirty);

    bm.DecrementPinCount(allocated.pfn);
    entry = try bm.pfn_table.getEntry(pfn_index);
    try std.testing.expectEqual(@as(usize, 0), entry.pin_count);

    try bm.FreePageFrame(allocated.pfn);

    entry = try bm.pfn_table.getEntry(pfn_index);
    try std.testing.expectEqual(.not_allocated, entry.state);
}

test "PFNToPage returns existing page and increments pin count" {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    var bm = try BufferManager.initWithSizes(allocator,8,8);
    defer bm.deinit();

    const allocated = try bm.AllocPageFrame();
    allocated.page.mem[0] = 99;

    const page_again = try bm.PFNToPage(allocated.pfn);

    try std.testing.expectEqual(@as(u8, 99), page_again.mem[0]);

    const pfn_index: usize = @intCast(allocated.pfn);
    const entry = try bm.pfn_table.getEntry(pfn_index);
    try std.testing.expectEqual(@as(usize, 2), entry.pin_count);
}


test "AllocPageFrame evicts released dirty pages and PFNToPage reloads them" {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    // Only 2 memory frames, but 4 possible disk pages.
    var bm = try BufferManager.initWithSizes(allocator, 2, 4);
    defer bm.deinit();

    const p0 = try bm.AllocPageFrame();
    p0.page.mem[0] = 11;
    bm.DecrementPinCount(p0.pfn);

    const p1 = try bm.AllocPageFrame();
    p1.page.mem[0] = 22;
    bm.DecrementPinCount(p1.pfn);

    // Memory is now full. Both pages are unpinned and dirty.
    // This allocation must evict one of them.
    const p2 = try bm.AllocPageFrame();
    p2.page.mem[0] = 33;
    bm.DecrementPinCount(p2.pfn);

    // p0 may or may not have been evicted depending on chosen policy.
    // With evictFirstUnpinned, p0 should be the one evicted.
    const p0_index: usize = @intCast(p0.pfn);
    var p0_entry = try bm.pfn_table.getEntry(p0_index);

    try std.testing.expectEqual(.on_disk, p0_entry.state);
    try std.testing.expectEqual(@as(usize, 0), p0_entry.pin_count);
    try std.testing.expectEqual(false, p0_entry.dirty);

    // Fetching p0 should read it back from disk.
    const p0_again = try bm.PFNToPage(p0.pfn);

    try std.testing.expectEqual(@as(u8, 11), p0_again.mem[0]);

    p0_entry = try bm.pfn_table.getEntry(p0_index);
    try std.testing.expectEqual(.in_memory, p0_entry.state);
    try std.testing.expectEqual(@as(usize, 1), p0_entry.pin_count);
}


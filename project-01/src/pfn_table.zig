const std = @import("std");

pub const PFNTableError = error {
    PfnOutOfBounds,
    PfnWrongAssumedLocation
};

pub const PFNState = enum {
    not_allocated,
    on_disk,
    in_memory,
};

pub const PFNEntry = struct {
    state : PFNState,
    location : usize
};

pub const PFNTable = struct {

    pfn_entries : [] PFNEntry,
   
   pub fn init (page_nums : usize, allocator : std.mem.Allocator )  !PFNTable {
         
       const pfn_entries = try allocator.alloc(PFNEntry,page_nums);
       for (pfn_entries) |*entry| {
            entry.* = .{
                .state = .not_allocated,
                .location = 0, // probably cleaner way to do this in zig but for now assign 0
            };
        }
        return PFNTable {
            .pfn_entries = pfn_entries
        };
    }
    pub fn deinit (self : *PFNTable, allocator : std.mem.Allocator) void {
       allocator.free(self.pfn_entries);
    }

    fn checkBounds(self : *PFNTable, pfn : usize) !void {
        if(pfn >= self.pfn_entries.len) {
            return PFNTableError.PfnOutOfBounds;
        }
    }

    pub fn getEntry(self : *PFNTable, pfn : usize) !PFNEntry {
        try self.checkBounds(pfn);
        return self.pfn_entries[pfn];
    }
    pub fn markInMemory(self : *PFNTable, pfn : usize, frame_index : usize) !void {
        try self.checkBounds(pfn);
        self.pfn_entries[pfn] = .{
            .state = .in_memory,
            .location = frame_index,
        };
    }
    pub fn markOnDisk(self : *PFNTable, pfn : usize, disk_location : usize) !void {
        try self.checkBounds(pfn);
        self.pfn_entries[pfn] = .{
            .state = .on_disk,
            .location = disk_location,
        };
    }
    pub fn markNotAllocated(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        self.pfn_entries[pfn] = .{
            .state = .not_allocated,
            .location = 0,
        };
    }
    pub fn getFrameNumber(self : *PFNTable, pfn : usize) !usize {
        try self.checkBounds(pfn);
        if(self.pfn_entries[pfn].state != .in_memory) {
            return PFNTableError.PfnWrongAssumedLocation;
        }
        return self.pfn_entries[pfn].location;
    }


    pub fn getDiskLoc(self : *PFNTable, pfn : usize) !usize {
        try self.checkBounds(pfn);
        if(self.pfn_entries[pfn].state != .on_disk) {
            return PFNTableError.PfnWrongAssumedLocation;
        }
        return self.pfn_entries[pfn].location;
    }
};



// testing
//
//
test "Init initalizes all entries as not allocated" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);

    for(0..page_count) |i| {
        const entry = try table.getEntry(i);
        try std.testing.expectEqual(.not_allocated,entry.state);
    }
}

test "Marks pfn as in memory correctly" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;
    const dummy_entry = 1;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);

    try table.markInMemory(dummy_entry, dummy_entry);
    const entry = try table.getEntry(dummy_entry);
    try std.testing.expectEqual(.in_memory,entry.state);
    try std.testing.expectEqual(dummy_entry,entry.location);
}

test "Marks pfn as in on disk correctly" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;
    const dummy_entry = 1;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);

    try table.markOnDisk(dummy_entry, dummy_entry);
    const entry = try table.getEntry(dummy_entry);
    try std.testing.expectEqual(.on_disk,entry.state);
    try std.testing.expectEqual(dummy_entry,entry.location);
}


test "Marks pfn as in not allocated correctly" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;
    const dummy_entry = 1;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);
    // first mark as in memory to change default
    try table.markInMemory(dummy_entry, dummy_entry);
    // then mark as not allocated
    try table.markNotAllocated(dummy_entry);
    const entry = try table.getEntry(dummy_entry);
    try std.testing.expectEqual(.not_allocated,entry.state);
    try std.testing.expectEqual(0,entry.location);
}

test "getFrameNumber fails if PFN is not in memory" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);

    try table.markOnDisk(1,1);
    try std.testing.expectError(PFNTableError.PfnWrongAssumedLocation, table.getFrameNumber(1));
}
test "getDiskLoc fails if PFN is not on disk" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);

    try table.markInMemory(1,1);
    try std.testing.expectError(PFNTableError.PfnWrongAssumedLocation, table.getDiskLoc(1));
}

test "PFNTable rejects out of bounds pfns" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();
    const page_count = 4;

    var table = try PFNTable.init(page_count,allocator);
    defer table.deinit(allocator);

    try std.testing.expectError(PFNTableError.PfnOutOfBounds, table.getEntry(page_count+1));
    
}

const std = @import("std");

pub const PFNTableError = error {
    PfnOutOfBounds,
    PfnWrongAssumedLocation,
    PfnStillPinned,
    PfnStillDirty,
    PfnPinCountAlreadyZero,
    PfnTableFull,
};

pub const PFNState = enum {
    not_allocated,
    on_disk,
    in_memory,
};

pub const PFNEntry = struct {
    state : PFNState,
    location : usize,
    dirty : bool,
    pin_count : usize,

    // LRU stuff
    prev : ?usize,
    next : ?usize,
};

pub const PFNTable = struct {

    pfn_entries : [] PFNEntry,

    //LRU stuff
    head : ?usize,
    tail : ?usize,
   
   pub fn init (page_nums : usize, allocator : std.mem.Allocator )  !PFNTable {
         
       const pfn_entries = try allocator.alloc(PFNEntry,page_nums);
       for (pfn_entries) |*entry| {
            entry.* = .{
                .state = .not_allocated,
                .location = 0, // probably cleaner way to do this in zig but for now assign 0
                .dirty = false,
                .pin_count = 0,
                .next = null,
                .prev = null,
            };
        }
        return PFNTable {
            .pfn_entries = pfn_entries,
            .head = null,
            .tail = null,
        };
    }
    pub fn deinit (self : *PFNTable, allocator : std.mem.Allocator) void {
       allocator.free(self.pfn_entries);
    }
    //helper
    fn checkBounds(self : *PFNTable, pfn : usize) !void {
        if(pfn >= self.pfn_entries.len) {
            return PFNTableError.PfnOutOfBounds;
        }
    }

    fn checkInMemory(self : *PFNTable, pfn : usize) !void {
        if(self.pfn_entries[pfn].state != .in_memory) {
            return PFNTableError.PfnWrongAssumedLocation;
        }
    }
    fn checkOnDisk(self: *PFNTable, pfn: usize) !void {

        if (self.pfn_entries[pfn].state != .on_disk) {
            return PFNTableError.PfnWrongAssumedLocation;
        }
    }

    fn checkNotPinned(self: *PFNTable, pfn: usize) !void {

        if (self.pfn_entries[pfn].pin_count != 0) {
            return PFNTableError.PfnStillPinned;
        }
    }

    fn checkNotDirty(self: *PFNTable, pfn: usize) !void {

        if (self.pfn_entries[pfn].dirty) {
            return PFNTableError.PfnStillDirty;
        }
    }
    // api
    pub fn getEntry(self : *PFNTable, pfn : usize) !PFNEntry {
        try self.checkBounds(pfn);
        return self.pfn_entries[pfn];
    }
    pub fn getEntryPtr(self: *PFNTable, pfn: usize) !*PFNEntry {
        try self.checkBounds(pfn);
        return &self.pfn_entries[pfn];
    }
    pub fn findFreePFN(self : *PFNTable) !usize {
        for (self.pfn_entries,0..) |entry,index| {
            if(entry.state == .not_allocated) {
                return index;
            }
        }
        return PFNTableError.PfnTableFull; // for now until eviction logic is implemented
    }
    pub fn markInMemory(self : *PFNTable, pfn : usize, frame_index : usize) !void {
        try self.checkBounds(pfn);

        self.pfn_entries[pfn].state = .in_memory;
        self.pfn_entries[pfn].location = frame_index;
    }
    pub fn markOnDisk(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        try self.checkNotPinned(pfn);
        try self.checkNotDirty(pfn);
        
        self.pfn_entries[pfn].state = .on_disk;
        self.pfn_entries[pfn].location = pfn;
    }

    pub fn markNotAllocated(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        try self.checkNotDirty(pfn);
        try self.checkNotPinned(pfn);
        
        if (self.pfn_entries[pfn].dirty) {
            return PFNTableError.PfnStillDirty;
        }
        
        self.pfn_entries[pfn].state = .not_allocated;
        self.pfn_entries[pfn].location = 0;
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
    
    pub fn markDirty(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        if (self.pfn_entries[pfn].state != .in_memory) {
            return PFNTableError.PfnWrongAssumedLocation;
        }
        self.pfn_entries[pfn].dirty = true;
    }

    pub fn clearDirty(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        try self.checkInMemory(pfn);
        self.pfn_entries[pfn].dirty = false;
    }

    pub fn incrementPinCount(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        try self.checkInMemory(pfn);
        self.pfn_entries[pfn].pin_count += 1;
    }

    pub fn decrementPinCount(self : *PFNTable, pfn : usize) !void {
        try self.checkBounds(pfn);
        try self.checkInMemory(pfn);
        if (self.pfn_entries[pfn].pin_count == 0) {
            return PFNTableError.PfnPinCountAlreadyZero;
        }
        self.pfn_entries[pfn].pin_count -= 1;
    }
    
    pub fn getPinCount(self : *PFNTable, pfn : usize) !usize {
        try self.checkBounds(pfn);
        try self.checkInMemory(pfn);
        return self.pfn_entries[pfn].pin_count;
    }

    pub fn isDirty(self : *PFNTable, pfn : usize) !bool {
        try self.checkBounds(pfn);
        try self.checkInMemory(pfn);
        return self.pfn_entries[pfn].dirty;
    }

    pub fn lruAppend(self: *PFNTable, pfn: usize) !void {
        try self.checkBounds(pfn);

        const old_tail = self.tail;

        const entry = try self.getEntryPtr(pfn);
        entry.prev = old_tail;
        entry.next = null;

        if (old_tail) |tail_pfn| {
            const tail_entry = try self.getEntryPtr(tail_pfn);
            tail_entry.next = pfn;
        } else {
            self.head = pfn;
        }

        self.tail = pfn;
    }

    pub fn lruRemove(self: *PFNTable, pfn: usize) !void {
        try self.checkBounds(pfn);

        const entry = try self.getEntryPtr(pfn);

        const prev = entry.prev;
        const next = entry.next;

        if (prev) |prev_pfn| {
            const prev_entry = try self.getEntryPtr(prev_pfn);
            prev_entry.next = next;
        } else {
            self.head = next;
        }

        if (next) |next_pfn| {
            const next_entry = try self.getEntryPtr(next_pfn);
            next_entry.prev = prev;
        } else {
            self.tail = prev;
        }

        entry.prev = null;
        entry.next = null;
    }
    
    pub fn lruTouch(self: *PFNTable, pfn: usize) !void {
        if (self.tail == pfn) return;

        try self.lruRemove(pfn);
        try self.lruAppend(pfn);
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
    const dummy_entry : usize = 1;

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

    try table.markOnDisk(dummy_entry);
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

    try table.markOnDisk(1);
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

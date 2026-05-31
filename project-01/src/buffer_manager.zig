const Page = @import("page.zig").Page;
const std = @import("std");
const PageAllocator = @import("page_allocator.zig").PageAllocator;
const PFNTable = @import("pfn_table.zig").PFNTable;
const default_frame_count = 64;
const default_disk_count = 64;

pub const BufferManager = struct {
    page_allocator : PageAllocator,
    pfn_table : PFNTable,
    
    pub fn init(allocator : std.mem.Allocator) !BufferManager {
       return BufferManager {
            .page_allocator = try PageAllocator.init(default_frame_count,allocator),
            .pfn_table = try PFNTable.init(default_disk_count,allocator),
        }; 
    }
    pub fn deinit(self : *BufferManager, allocator : std.mem.Allocator) void {
        self.page_allocator.deinit(allocator);
        self.pfn_table.deinit(allocator);
    }

};

// Allocates a page frame. Also allocates and returns a corresponding page
fn AllocPageFrame(bfr_mngr: *BufferManager) !struct { pfn: u64, page: *Page} {
    _ = bfr_mngr;
    @panic("TODO");
}
// Final free of a page frame
fn FreePageFrame(pfn: u64, bfr_mngr: *BufferManager) !void {
    _ = pfn;
    _ = bfr_mngr;
    @panic("TODO");
}
// Get the page of a pfn either from memory or disk. Incremenst the pin count by
// one. The pin count is needed to not evict pages that are currently in use
fn PFNToPage(pfn: u64, bfr_mngr: *BufferManager) !*Page {
    _ = pfn;
    _ = bfr_mngr;
    @panic("TODO");
}
// Marks the page as dirty (e.g. by setting its dirty bit)
fn MarkDirty(pfn: u64, bfr_mngr: *BufferManager) void {
    _ = pfn;
    _ = bfr_mngr;
    @panic("TODO");
}
// Flush a dirty page to disk and clear its dirty bit
fn FlushPage(pfn: u64, bfr_mngr: *BufferManager) !void {
    _ = pfn;
    _ = bfr_mngr;
    @panic("TODO");
}
// Releases a page by decrementing the pin count. Further acceses must first
// call PFNToPage() again.
fn DecrementPinCount(pfn: u64, bfr_mngr: *BufferManager) void {
    _ = pfn;
    _ = bfr_mngr;
    @panic("TODO");
}
// Optional
fn PFNToPageAsync(pfn: u64, bfr_mngr: *BufferManager) !?*Page {
    _ = pfn;
    _ = bfr_mngr;
    @panic("TODO");
}

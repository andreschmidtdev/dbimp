const std = @import("std");
const Page = @import("page.zig").Page;

pub const PageAllocatorError = error { 
    InvalidFrameIndex,
    FrameAlreadyFree,
    PageAllocatorIsFull
    };


pub const PageAllocator = struct {
    frame_count : usize,
    pages : [] Page,
    used : [] bool,
    pub fn init(frame_count : usize, allocator : std.mem.Allocator) !PageAllocator {
        const pages = try allocator.alloc(Page, frame_count);
        errdefer allocator.free(pages);

        const used = try allocator.alloc(bool, frame_count);
        errdefer allocator.free(used);

        return PageAllocator {
            .frame_count = frame_count,
            .pages = pages,
            .used = used
        };
    }

    pub fn deinit(self : *PageAllocator, allocator : std.mem.Allocator) void {
        allocator.free(self.pages);
        allocator.free(self.used);
    }

    pub fn full(self: *PageAllocator) bool {
        
        for(self.used) |is_used| {
            if (!is_used) {
                return false;
            }
        }
        return true;
    }

    pub fn allocFrame(self : *PageAllocator) !struct {frame_index : usize, page : *Page} {
        // look for unused page
        for (self.used,0..) |is_used,i| {
            if(!is_used) {
                self.used[i] = true;
       // return index of unused page and pointer to it
        return .{
            .frame_index = i,
            .page = &self.pages[i],
        };
        }
        }
        return PageAllocatorError.PageAllocatorIsFull;
 
    }
    pub fn getFrame(self: *PageAllocator, frame_index: usize) !*Page {
        if (frame_index >= self.pages.len) {
            return PageAllocatorError.InvalidFrameIndex;
        }

        return &self.pages[frame_index];
    }

    pub fn freeFrame(self: *PageAllocator, frame_index : usize) !void {
        if(frame_index >= self.frame_count) {
            return PageAllocatorError.InvalidFrameIndex;
        }

        if(!self.used[frame_index]) {
            return PageAllocatorError.FrameAlreadyFree;
        }
        
        self.used[frame_index] = false;
    }
};


// Tests
test "PageAllocator creates N free frames" {
        var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
        defer _ = debug_allocator.deinit();
        const allocator = debug_allocator.allocator();
        var page_allocator = try PageAllocator.init(@as(usize,64),allocator);
        defer page_allocator.deinit(allocator);
        
        try std.testing.expectEqual(@as(usize,64), page_allocator.pages.len);
        try std.testing.expectEqual(@as(usize,64), page_allocator.used.len);
        try std.testing.expectEqual(@as(usize,64), page_allocator.frame_count);
        for(page_allocator.used) |is_used| {
        try std.testing.expect(!is_used);
        }

}

test "Allocation works as intended (doesnt allow out of bound, marks frame as used, returns error if allocator is full)" {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();
    var page_allocator = try PageAllocator.init(@as(usize,1),allocator);
    defer page_allocator.deinit(allocator);

    //test if page allocator marks page as used
    _ = try page_allocator.allocFrame();
    try std.testing.expectEqual(true, page_allocator.used[0]);
    //test if page allocator allows out of bound retrieval of frame index
    try std.testing.expectError(PageAllocatorError.InvalidFrameIndex,page_allocator.freeFrame(10));
    // test if page allocator allows throws error when full
    try std.testing.expectError(PageAllocatorError.PageAllocatorIsFull,page_allocator.allocFrame());
}

test "PageAllocator frees frame of specific index" {
    var debug_allocator : std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();
    var page_allocator = try PageAllocator.init(@as(usize,64),allocator);
    defer page_allocator.deinit(allocator);
    const result = try page_allocator.allocFrame();
    try page_allocator.freeFrame(result.frame_index);
    try std.testing.expectEqual(false,page_allocator.used[result.frame_index]);

}

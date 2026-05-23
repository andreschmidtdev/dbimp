const std = @import("std");
const BufferManager = @import("buffer_manager.zig").BufferManager;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer {
        const status = debug_allocator.deinit();
        if (status == .leak) {
            std.debug.print("Memory leak detected\n", .{});
        }
    }

    const allocator = debug_allocator.allocator();

    var buffer_manager = try BufferManager.init(allocator);
    defer buffer_manager.deinit(allocator);

    std.debug.print("BufferManager initialized with {} frames\n", .{
        buffer_manager.page_allocator.frame_count,
    });
}

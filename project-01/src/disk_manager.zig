const std = @import("std");

const Page = @import("page.zig").Page;
const page_size = @import("page.zig").page_size;

const DiskManagerError = error{
    PageOutOfBounds,
    InvalidDiskCapacity,
};
pub const DiskManager = struct {
    file: std.fs.File,
    disk_capacity: usize,

    pub fn init(filename: []const u8, disk_capacity: usize) !DiskManager {
        if (disk_capacity == 0 or disk_capacity % page_size != 0) {
            return DiskManagerError.InvalidDiskCapacity;
        }
        const cwd = std.fs.cwd();

        // create data dir if doesnt exist
        try cwd.makePath("data");

        // open a handle rooted at ./data
        var data_dir = try cwd.openDir("data", .{});
        defer data_dir.close();

        var file = try data_dir.createFile(filename, .{
            .read = true,
            .truncate = true
        });
        errdefer file.close();

        // set the logical disk file size.
        // unsure if this is necessary
        try file.setEndPos(@intCast(disk_capacity));

        return .{
            .file = file,
            .disk_capacity = disk_capacity
        };
    }

    pub fn deinit(self: *DiskManager) void {
        self.file.close();
    }

    fn pageOffset(self: *const DiskManager, pfn: usize) !u64 {
        const page_count = self.disk_capacity / page_size;

        if (pfn >= page_count) {
            return DiskManagerError.PageOutOfBounds;
        }
        const offset = try std.math.mul(usize,pfn,page_size);

        return @intCast(offset);
    }

    pub fn writeToPage(self: *DiskManager, pfn: usize, page: *const Page) !void {
        const offset = try self.pageOffset(pfn);
        _ = try self.file.pwriteAll(&page.mem, offset);

    }

    pub fn readPage(self: *DiskManager, pfn: usize, page: *Page) !void {
        const offset = try self.pageOffset(pfn);
        _ = try self.file.preadAll(&page.mem, offset);
    }
};

// testing
//
//
//
test "rejcets out of bounds" {

    const testing = std.testing;

    var disk : DiskManager = try DiskManager.init("test.db",page_size*4);
    defer disk.deinit();
    defer std.fs.cwd().deleteFile("test.db") catch {};
    var page = Page{.mem = undefined};

    try testing.expectError(DiskManagerError.PageOutOfBounds, disk.readPage(4, &page));
    try testing.expectError(DiskManagerError.PageOutOfBounds, disk.writeToPage(4, &page));
}

test "read and write (to) page" {
    const testing = std.testing;

    var disk : DiskManager = try DiskManager.init("test.db", page_size*4);

    var written = Page{.mem = undefined};
    @memset(&written.mem, 42);

    try disk.writeToPage(1, &written);

    var read = Page{.mem = undefined};

    try disk.readPage(1, &read);

    try testing.expectEqualSlices(u8, &read.mem,&written.mem);
}

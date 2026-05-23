pub const page_size = 1 << 12; // 4096 Bytes of page size

pub const Page = struct {
    mem : [page_size]u8 align(page_size)
};

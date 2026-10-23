// core operations
// Get
// Put
//

const std = @import("std");
const skipmap = @import("internal/skipmap.zig");
const wal = @import("wal.zig");

pub const MemTableCfg = struct { appendToWal: bool };

pub const MemTable = struct {
    wal: wal.Wal,
    map: *skipmap.SkipMap,

    fn init(id: usize) *MemTable {
        const mt: MemTable = .{
            .wal = wal.New(id),
            .map = skipmap.SkipMap.init(std.heap.page_allocator), // TODO: Switch to global allocator pool
        };

        return *mt;
    }

    fn put(self: *MemTable, k: skipmap.K, v: skipmap.V, cfg: MemTableCfg) !void {
        if (cfg.appendToWal) {
            // TODO : implement wal writing
            // self.wal.append
        }
        try self.map.put(k, v);
    }

    fn get(self: *MemTable, k: skipmap.K) ?skipmap.V {
        const v = self.map.get(k);
        return v;
    }

    fn delete(self: *MemTable, k: skipmap.K) !void {
        // TODO: implement wal writing
        self.map.remove(k);
    }

    fn iterator(self: *MemTable, k: skipmap.K) *skipmap.Iterator {
        return self.map.iterator(k);
    }
};

test "put and get" {
    var mt = MemTable.init();
    try mt.put("foo", "bar");
    try std.testing.expectEqual("bar", mt.get("foo"));
}

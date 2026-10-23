const std = @import("std");

pub const Wal = struct {
    file: std.Io.File,

    fn New(id: usize) *Wal {
        const io = std.Io.Threaded.global_single_threaded.io();

        const f_n = std.fmt.allocPrint(std.heap.page_allocator, "wal-{d}.wal", id);

        const f = try std.Io.Dir.cwd().createFile(io, f_n, .{}) catch |err| {
            std.debug.print("Failed to create WAL : {}\n", .{err});
            return err;
        };
        return *Wal{
            .file = f,
        };
    }

    // fn Append(self : *Wal)
};

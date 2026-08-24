// put(key, value)
// get(key)
// remove(key)
// contains(key)
// len()
//
//

// skiplist basics
// level-k node : a node with k forward pointers
//
// L3:   1  ───────────────────→ 13
// L2:   1  ─────→ 7 ──────────→ 13
// L1:   1  → 3 → 5 → 7 → 9 → 11 → 13
//
// at insertion, level is randomly choosen based on an RNG
//
// level is fixed post insertion
//
// Node {
//  key K
//  value V
//
//  forward *Node[]
// }
//
// SkipList {
//  head *Node
//  length
//  level
//  ....
// }
//
// init(allocator) -> SkipList
// put(key KeyType, val ValType)
// iterator()
// get(key u) -> ?V
// contains(key KeyType) -> bool
// remove(key KeyType)
// deinit()
//
//
//

const std = @import("std");

const MAX_LEVELS = 12;

fn randomLevel(prng: *std.Random.DefaultPrng) usize {
    const random = prng.random();
    var level: usize = 0;

    while (random.boolean() and level < MAX_LEVELS - 1) {
        level += 1;
    }
    return level;
}

const K = []const u8;
const V = []const u8;

const node = struct { key: K, value: V, forward: []?*node };

pub const Iterator = struct {
    current: ?*node,
    pub fn init(startNode: ?*node) !Iterator {
        const it = Iterator{ .current = startNode };
        return it;
    }

    pub fn next(self: *Iterator) ?*node {
        const n = self.current orelse return null;
        self.current = n.forward[0];
        return n;
    }
};

fn makeNode(a: std.mem.Allocator, l: usize, k: K, v: V) !*node {
    const n = try a.create(node);
    n.* = .{ .key = k, .value = v, .forward = try a.alloc(?*node, l + 1) };
    @memset(n.forward, null);
    return n;
}

pub const SkipList = struct {
    header: *node,
    level: usize,
    len: usize,

    prng: std.Random.DefaultPrng,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !SkipList {
        const sl = SkipList{ .header = try makeNode(allocator, MAX_LEVELS - 1, undefined, undefined), .level = 0, .len = 0, .prng = std.Random.DefaultPrng.init(123456), .allocator = allocator };
        return sl;
    }

    pub fn get(self: *SkipList, key: K) ?V {
        var i = self.level;
        var x = self.header;
        while (true) {
            while (x.forward[i]) |next| {
                if (std.mem.order(u8, next.key, key) != .lt) {
                    break;
                }
                x = next;
            }
            if (i == 0) break;
            i -= 1;
        }

        if (x.forward[0]) |next| {
            if (std.mem.eql(u8, next.key, key)) {
                return next.value;
            }
        }
        return null;
    }

    pub fn put(self: *SkipList, key: K, val: V) !void {
        var x = self.header;
        var i = self.level;
        var update: [MAX_LEVELS]*node = undefined;

        while (true) {
            while (x.forward[i]) |next| {
                if (std.mem.order(u8, next.key, key) != .lt) {
                    break;
                }
                x = next;
            }
            update[i] = x;
            if (i == 0) {
                break;
            }
            i -= 1;
        }
        if (x.forward[0]) |next| {
            if (std.mem.eql(u8, next.key, key)) {
                next.value = val;
                return;
            }
        }

        const newLevel = randomLevel(&self.prng);

        if (newLevel > self.level) {
            i = self.level + 1;
            while (i <= newLevel) {
                update[i] = self.header;
                i += 1;
            }
            self.level = newLevel;
        }
        x = try makeNode(self.allocator, newLevel, key, val);

        i = 0;
        while (i <= newLevel) {
            x.forward[i] = update[i].forward[i];
            update[i].forward[i] = x;
            i += 1;
        }
        self.len += 1;
    }

    pub fn contains(self: *SkipList, key: K) bool {
        var x = self.header;
        var i = self.level;

        while (true) {
            while (x.forward[i]) |next| {
                if (std.mem.order(u8, next.key, key) != .lt) {
                    break;
                }

                x = next;
            }
            if (i == 0) {
                break;
            }
            i -= 1;
        }
        if (x.forward[0]) |next| {
            if (std.mem.eql(u8, next.key, key)) {
                return true;
            }
        }

        return false;
    }

    pub fn remove(self: *SkipList, key: K) void {
        var x = self.header;
        var i = self.level;

        var update: [MAX_LEVELS]*node = undefined;
        while (true) {
            while (x.forward[i]) |next| {
                if (std.mem.order(u8, next.key, key) != .lt) {
                    break;
                }
                x = next;
            }
            update[i] = x;
            if (i == 0) {
                break;
            }
            i -= 1;
        }

        const target = x.forward[0] orelse return;

        if (!std.mem.eql(u8, target.key, key)) {
            return;
        }

        i = 0;
        while (i <= self.level) : (i += 1) {
            if (update[i].forward[i] == target) {
                update[i].forward[i] = target.forward[i];
            }
        }
        self.allocator.destroy(target);

        while (self.level > 0 and self.header.forward[self.level] == null) {
            self.level -= 1;
        }
    }

    pub fn find(self: *SkipList, key: K) ?*node {
        var x = self.header;
        var i = self.level;

        while (true) {
            while (x.forward[i]) |next| {
                if (std.mem.order(u8, next.key, key) != .lt) {
                    break;
                }
                x = next;
            }
            if (i == 0) {
                break;
            }
            i -= 1;
        }
        if (x.forward[0]) |next| {
            if (std.mem.eql(u8, next.key, key)) {
                return next;
            }
        }
        return null;
    }

    // lowerBound(x) -> first value >= x
    pub fn lowerBound(self: *SkipList, key: K) ?*node {
        var x = self.header;
        var i = self.level;
        var update: [MAX_LEVELS]*node = undefined;

        while (true) {
            while (x.forward[i]) |next| {
                if (std.mem.order(u8, next.key, key) != .lt) {
                    break;
                }
                x = next;
            }
            update[i] = x;
            if (i == 0) {
                break;
            }
            i -= 1;
        }
        return x.forward[0];
    }

    pub fn iterator(self: *SkipList, start_key: K) !Iterator {
        const startNode = self.lowerBound(start_key);
        return try Iterator.init(startNode);
    }
};

test "put and get" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try sl.put("foo", "bar");
    try std.testing.expectEqual("bar", sl.get("foo"));
}

test "get missing key" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try std.testing.expectEqual(null, sl.get("foo"));
}

test "put update" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try sl.put("foo", "bar");
    try std.testing.expectEqual("bar", sl.get("foo"));
    try sl.put("foo", "baz");
    try std.testing.expectEqual("baz", sl.get("foo"));
}

test "contains" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try sl.put("foo", "bar");
    try std.testing.expectEqual(true, sl.contains("foo"));
    try std.testing.expectEqual(false, sl.contains("bar"));
}

test "remove" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try sl.put("foo", "bar");
    try std.testing.expectEqual(true, sl.contains("foo"));
    sl.remove("foo");
    try std.testing.expectEqual(false, sl.contains("foo"));
}

test "iterate" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try sl.put("100", "bar");
    try sl.put("101", "bar");
    try sl.put("102", "bar");
    try sl.put("103", "bar");
    try sl.put("104", "bar");

    var iter = try sl.iterator("101");
    while (iter.next()) |n| {
        std.debug.print("key: {s}, value: {s}\n", .{ n.key, n.value });
    }
}

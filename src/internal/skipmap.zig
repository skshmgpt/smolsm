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
};

test "put and get" {
    var sl = try SkipList.init(std.heap.page_allocator);

    try sl.put("foo", "bar");
    try std.testing.expectEqual("bar", sl.get("foo"));
}

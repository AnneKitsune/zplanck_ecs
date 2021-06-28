//! Holds a list of bitset entities.
//! It also holds a list of entities that were recently killed, which allows
//! to remove components of deleted entities at the end of a game frame.

const std = @import("std");
const Entity = @import("./Entity.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Bitset = std.bit_set.StaticBitSet(MAX_ENTITIES);
const expect = std.testing.expect;

const benchmark = @import("zig-benchmark");
const Entities = @This();

const MAX_ENTITIES = @import("./main.zig").MAX_ENTITIES;

bitset: Bitset, // Stack bitset = 8KB
generation: ArrayList(u32), // Heap generation list = 255KB
killed: ArrayList(Entity),
next_id: u16 = 0,
/// helps to know if we should directly append after
/// next_id or if we should look through the bitset.
has_deleted: bool = false,

const InnerType: type = Entity;

/// Allocates a new Entities struct.
pub fn init(allocator: *Allocator) !@This() {
    var gen = try ArrayList(u32).initCapacity(allocator, MAX_ENTITIES);
    errdefer gen.deinit();
    gen.appendNTimesAssumeCapacity(0, MAX_ENTITIES);

    const killed = ArrayList(Entity).init(allocator);
    errdefer killed.deinit();

    const bitset = Bitset.initEmpty();
    return @This(){
        .bitset = bitset,
        .generation = gen,
        .killed = killed,
    };
}

/// Creates a new `Entity` and returns it.
/// This function will not reuse the index of an entity that is still in
/// the killed entities.
pub fn create(this: *@This()) Entity {
    if (!this.has_deleted) {
        const i = this.next_id;
        this.next_id += 1;
        this.bitset.set(i);
        return Entity{ .index = i, .generation = this.generation.items[i] };
    } else {
        var check: u16 = 0;
        var found = false;
        while (!found) : (check += 1) {
            comptime const overflow_check = std.builtin.mode == .Debug or std.builtin.mode == .ReleaseSafe;
            if (overflow_check and check == MAX_ENTITIES) {
                @panic("Max entity count reached!");
            }
            if (!this.bitset.isSet(check)) {
                var in_killed = false;
                // .any(fn) would reduce this by a lot, but I'm not sure if that's possible
                // didn't find that in std.mem
                for (this.killed.items) |k| {
                    if (k.index == check) {
                        in_killed = true;
                        break;
                    }
                }
                if (!in_killed) {
                    found = true;
                }
            }
        }
        check -= 1;
        this.bitset.set(check);
        if (check >= this.next_id) {
            this.next_id = check;
            this.has_deleted = false;
        }
        return Entity{ .index = check, .generation = this.generation.items[check] };
    }
}

/// Checks if the `Entity` is still bitset.
/// Returns true if it is bitset.
/// Returns false if it has been killed.
pub fn is_bitset(this: *@This(), entity: Entity) bool {
    return this.bitset.isSet(entity.index) and this.generation.items[entity.index] == entity.generation;
}

/// Kill an entity.
pub fn kill(this: *@This(), entity: Entity) !void {
    if (this.is_bitset(entity)) {
        this.bitset.unset(entity.index);
        this.generation.items[entity.index] += 1;
        try this.killed.append(entity);
        this.has_deleted = true;
    }
}

/// Clears the killed entity list.
pub fn clear_killed(this: *@This()) void {
    this.killed.items.len = 0;
}

/// Deallocates an Entities struct.
pub fn deinit(this: *@This()) void {
    this.generation.deinit();
    this.killed.deinit();
}

/// Gets the element immutably
pub fn get(this: *const @This(), idx: u32) ?Entity {
    return Entity{
        .index = idx,
        .generation = this.generation.items[idx],
    };
}

test "Create entity" {
    var entities = try @This().init(std.testing.allocator);
    defer entities.deinit();
    const entity1 = entities.create();
    try expect(entity1.index == 0);
    try expect(entity1.generation == 0);
    try expect(entities.bitset.isSet(0));
    try expect(!entities.bitset.isSet(1));
    const entity2 = entities.create();
    try expect(entity2.index == 1);
    try expect(entity2.generation == 0);
    try expect(entities.bitset.isSet(0));
    try expect(entities.bitset.isSet(1));
}

test "Kill create entity" {
    var entities = try @This().init(std.testing.allocator);
    defer entities.deinit();
    const entity1 = entities.create();
    try expect(entity1.index == 0);
    try expect(entity1.generation == 0);
    try expect(entities.bitset.isSet(0));
    try expect(!entities.bitset.isSet(1));
    try expect(!entities.has_deleted);
    try entities.kill(entity1);
    try expect(entities.has_deleted);
    const entity2 = entities.create();
    try expect(entity2.index == 1);
    try expect(entity2.generation == 0);
    try expect(!entities.bitset.isSet(0));
    try expect(entities.bitset.isSet(1));
    // This did go all the way to the end to create the entity, so has_deleted should go back to false.
    try expect(!entities.has_deleted);

    entities.clear_killed();

    // has_deleted is false, so we won't try to reuse index 0
    // let's turn has_deleted back to true manually and check if we reuse index 0.
    entities.has_deleted = true;

    const entity3 = entities.create();
    try expect(entity3.index == 0);
    try expect(entity3.generation == 1);
    try expect(entities.bitset.isSet(0));
    try expect(entities.bitset.isSet(1));
    try expect(!entities.bitset.isSet(2));
    try expect(!entities.bitset.isSet(3));
    // has_deleted stays to true since we didn't check until the end of the array
    try expect(entities.has_deleted);
    const entity4 = entities.create();
    try expect(entity4.index == 2);
    try expect(entity4.generation == 0);
    try expect(entities.bitset.isSet(0));
    try expect(entities.bitset.isSet(1));
    try expect(entities.bitset.isSet(2));
    try expect(!entities.bitset.isSet(3));
    // has_deleted turns back to false
    try expect(!entities.has_deleted);
}

test "Benchmark create entity" {
    const b = struct {
        fn bench(ctx: *benchmark.Context, count: u32) void {
            while (ctx.runExplicitTiming()) {
                var entities = Entities.init(std.testing.allocator) catch unreachable;
                defer entities.deinit();

                var i = @as(u32, 0);
                ctx.startTimer();
                while (i < count) : (i += 1) {
                    const e = entities.create();
                    benchmark.doNotOptimize(e.index);
                }
                ctx.stopTimer();
            }
        }
    }.bench;
    benchmark.benchmarkArgs("create Entity", b, &[_]u32{ 1, 100, 10000 });
}
test "Benchmark create Entities" {
    const b = struct {
        fn bench(ctx: *benchmark.Context) void {
            // using the arena allocator and -lc (libc) gives the fastest results.
            //var alloc = std.heap.c_allocator;

            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const alloc = &arena.allocator;

            while (ctx.run()) {
                var entities = Entities.init(alloc) catch unreachable;
                defer entities.deinit();
            }
        }
    }.bench;
    benchmark.benchmark("create Entities", b);
}

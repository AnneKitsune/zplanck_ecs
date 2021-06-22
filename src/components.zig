const std = @import("std");
const Entity = @import("./Entity.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Bitset = std.bit_set.StaticBitSet(MAX_ENTITIES);

// testing
const Entities = @import("./Entities.zig");
const benchmark = @import("deps/zig-benchmark/bench.zig");

// TODO dedup
const MAX_ENTITIES=65535;
const expect = std.testing.expect;

/// Holds components of a given type indexed by `Entity`.
/// We do not check if the given entity is alive here, this should be done using
/// `Entities`.
pub fn Components(comptime T: type) type {
    return struct {
        bitset: Bitset,
        components: ArrayList(?T),

        /// Allocates a new Components(T) struct.
        pub fn init(allocator: *Allocator) !@This() {
            var comps = try ArrayList(?T).initCapacity(allocator, 64);
            errdefer comps.deinit();
            comps.appendNTimesAssumeCapacity(null, 64);
        
            const bitset = Bitset.initEmpty();
            //const bitset = Bitset.initAllTo(0);
            return @This() {
                .bitset = bitset,
                .components = comps,
            };
        }

        /// Inserts a component for the given `Entity` index.
        /// Returns the previous component, if any.
        pub fn insert(self: *@This(), entity: Entity, component: T) !?T {
            var ins: ?T = component;
            if (self.bitset.isSet(entity.index)) {
                std.mem.swap(?T, &ins, &self.components.items[entity.index]);
                return ins;
            } else {
                try self.allocate_enough(entity.index);
                self.bitset.set(entity.index);
                self.components.items[entity.index] = component;
                return null;
            }
        }

        /// Ensures that we have the vec filled at least until the `until`
        /// variable. Usually, set this to `entity.index`.
        fn allocate_enough(self: *@This(), until: usize) !void {
            const qty = @intCast(i32, until) - @intCast(i32, self.components.items.len);
            if (qty > 0) {
                try self.components.appendNTimes(null, @intCast(usize, qty));
            }
        }
        
        /// Deinitializes Component(T).
        pub fn deinit(self: *@This()) void {
            self.components.deinit();
        }

        /// Gets a reference to the component of `Entity`, if any.
        /// Do not store the returned pointer.
        pub fn get(self: *@This(), entity: Entity) ?*T {
            if (self.bitset.isSet(entity.index)) {
                return &self.components.items[entity.index].?;
            } else {
                return null;
            }
        }

        /// Removes the component of `Entity`.
        /// If the entity already had this component, we return it.
        pub fn remove(self: *@This(), entity: Entity) ?T {
            if (self.bitset.isSet(entity.index)) {
                self.bitset.unset(entity.index);
                const ret = self.components.items[entity.index];
                self.components.items[entity.index] = null;
                return ret;
            } else {
                return null;
            }
        }
    };
}

test "Insert Component" {
    var entities = try Entities.init(std.testing.allocator);
    defer entities.deinit();
    var comps = try Components(u32).init(std.testing.allocator);
    defer comps.deinit();

    const e1 = entities.create();
    const e2 = entities.create();
    _ = try comps.insert(e1, 1);
    _ = try comps.insert(e2, 2);
    const ret = comps.get(e1).?.*;
    try expect(ret == 1);
    const ret2 = comps.get(e2).?.*;
    try expect(ret2 == 2);
}


fn optToBool(comptime T: type, v: ?T) bool {
    if (v) |_| {
        return true;
    } else {
        return false;
    }
}

test "Insert remove component" {
    var entities = try Entities.init(std.testing.allocator);
    defer entities.deinit();
    var comps = try Components(u32).init(std.testing.allocator);
    defer comps.deinit();

    const e1 = entities.create();
    const not_inserted = entities.create();
    try expect(!optToBool(u32, comps.remove(e1))); // no return value.
    try expect(!optToBool(u32, try comps.insert(e1, 1))); // no return value.
    try expect(optToBool(u32, comps.remove(e1))); // now a return value.
    try expect(!optToBool(u32, try comps.insert(e1, 1))); // no return value.
    try expect((try comps.insert(e1, 2)).? == 1); // a return value.
    try expect(!optToBool(u32, comps.remove(not_inserted))); // no return value.
    try expect(comps.remove(e1).? == 2); // a return value.

}

test "Benchmark component insertion" {
    const b = struct {
        fn bench(ctx: *benchmark.Context) void {
            var entities = Entities.init(std.testing.allocator) catch unreachable;
            defer entities.deinit();
            var comps = Components(u32).init(std.testing.allocator) catch unreachable;
            defer comps.deinit();

            const e1 = entities.create();

            while (ctx.runExplicitTiming()) {
                ctx.startTimer();
                _ = comps.insert(e1, 1) catch unreachable;
                ctx.stopTimer();
            }
        }}.bench;
    benchmark.benchmark("insert component", b);
}

// TODO move to entities file
test "Benchmark create entity" {
    const b = struct {
        fn bench(ctx: *benchmark.Context, count: u32) void {
            while (ctx.runExplicitTiming()) {
                var entities = Entities.init(std.testing.allocator) catch unreachable;
                defer entities.deinit();

                var i = @as(u32, 0);
                ctx.startTimer();
                while (i < count) : (i += 1) {
                    _ = entities.create();
                }
                ctx.stopTimer();
            }
        }}.bench;
    benchmark.benchmarkArgs("create Entity", b, &[_]u32{1, 100, 10000});
}
test "Benchmark create Entities" {
    const b = struct {
        fn bench(ctx: *benchmark.Context) void {
            while (ctx.run()) {
                var entities = Entities.init(std.testing.allocator) catch unreachable;
                defer entities.deinit();
            }
        }}.bench;
    benchmark.benchmark("create Entities", b);
}

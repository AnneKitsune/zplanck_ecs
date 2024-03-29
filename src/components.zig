const std = @import("std");
const Entity = @import("./entity.zig").Entity;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Bitset = std.bit_set.StaticBitSet(MAX_ENTITIES);

// testing
const Entities = @import("./entities.zig").Entities;
const benchmark = @import("zig_benchmark");
const builtin = @import("builtin");

const MAX_ENTITIES = @import("./main.zig").MAX_ENTITIES;
const expect = std.testing.expect;

/// Holds components of a given type indexed by `Entity`.
/// We do not check if the given entity is alive here, this should be done using
/// `Entities`.
pub fn Components(comptime T: type) type {
    return struct {
        bitset: Bitset,
        components: ArrayList(T),
        next_id: u32 = 0,

        pub const InnerType: type = T;

        /// Allocates a new Components(T) struct.
        pub fn init(allocator: Allocator) !@This() {
            var comps = try ArrayList(T).initCapacity(allocator, 64);
            errdefer comps.deinit();
            comps.appendNTimesAssumeCapacity(undefined, 64);

            const bitset = Bitset.initEmpty();
            //const bitset = Bitset.initAllTo(0);
            return @This(){
                .bitset = bitset,
                .components = comps,
            };
        }

        /// Inserts a component for the given `Entity` index.
        /// Returns the previous component, if any.
        pub fn insert(self: *@This(), entity: Entity, component: T) !void {
            try self.allocate_enough(entity.index);
            self.bitset.set(entity.index);
            self.components.items[entity.index] = component;
        }

        /// Ensures that we have the vec filled at least until the `until`
        /// variable. Usually, set this to `entity.index`.
        fn allocate_enough(self: *@This(), until: u32) !void {
            self.next_id = until + 1;
            const qty = @intCast(i32, until) - (@intCast(i32, self.components.items.len) - 1);
            if (qty > 0) {
                // TODO change this to just a size bump without setting any value.
                try self.components.appendNTimes(undefined, @intCast(usize, qty));
            }
        }

        /// Deinitializes Component(T).
        pub fn deinit(self: *@This()) void {
            self.components.deinit();
        }

        /// Gets a reference to the component of `Entity`, if any.
        /// Do not store the returned pointer.
        ///
        /// The entity argument must be a valid index.
        /// To ensure this, take it from an `Entity` using entity.index.
        pub fn get(self: *const @This(), entity: u32) ?*const T {
            if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
                if (self.bitset.isSet(entity)) {
                    return &self.components.items[entity];
                } else {
                    return null;
                }
            } else {
                return &self.components.items[entity];
            }
        }

        /// Gets a reference to the component of `Entity`, if any.
        /// Do not store the returned pointer.
        ///
        /// The entity argument must be a valid index.
        /// To ensure this, take it from an `Entity` using entity.index.
        pub fn getMut(self: *@This(), entity: u32) ?*T {
            if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
                if (self.bitset.isSet(entity)) {
                    return &self.components.items[entity];
                } else {
                    return null;
                }
            } else {
                return &self.components.items[entity];
            }
        }

        /// Removes the component of `Entity`.
        /// If the entity already had this component, we return it.
        pub fn remove(self: *@This(), entity: Entity) void {
            self.bitset.unset(entity.index);
        }

        /// Removes dead entities from this component storage.
        pub fn maintain(self: *@This(), entities: *const Entities) void {
            for (entities.killed.items) |e| {
                _ = self.remove(e);
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
    const ret = comps.get(e1.index).?.*;
    try expect(ret == 1);
    const ret2 = comps.get(e2.index).?.*;
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
    comps.remove(e1);
    try comps.insert(e1, 1);
}

test "Maintain" {
    var entities = try Entities.init(std.testing.allocator);
    defer entities.deinit();
    var comps = try Components(u32).init(std.testing.allocator);
    defer comps.deinit();

    const e1 = entities.create();
    _ = try comps.insert(e1, 3);
    try entities.kill(e1);
    comps.maintain(&entities);
    comps.remove(e1);
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
        }
    }.bench;
    benchmark.benchmark("insert component", b);
}

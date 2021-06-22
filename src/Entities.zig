//! Holds a list of alive entities.
//! It also holds a list of entities that were recently killed, which allows
//! to remove components of deleted entities at the end of a game frame.

const std = @import("std");
const Entity = @import("./Entity.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Bitset = std.bit_set.StaticBitSet(MAX_ENTITIES);
const expect = std.testing.expect;

const MAX_ENTITIES=65535;

// 2^24 entities = 16M

alive: Bitset, // Stack bitset = 2MB
generation: ArrayList(u32), // Heap generation set = 8 MB
killed: ArrayList(Entity),
max_id: u16 = 0,
/// helps to know if we should directly append after
/// max_id or if we should look through the bitset.
has_deleted: bool = false,

/// Allocates a new Entities struct.
pub fn init(allocator: *Allocator) !@This() {
    var gen = try ArrayList(u32).initCapacity(allocator, MAX_ENTITIES);
    errdefer gen.deinit();
    //std.mem.set(u32, gen.items, 0);
    gen.appendNTimesAssumeCapacity(0, MAX_ENTITIES);

    const killed = ArrayList(Entity).init(allocator);
    errdefer killed.deinit();

    const alive = Bitset.initEmpty();
    return @This() {
        .alive = alive,
        .generation = gen,
        .killed = killed,
    };
}

/// Creates a new `Entity` and returns it.
/// This function will not reuse the index of an entity that is still in
/// the killed entities.
pub fn create(self: *@This()) Entity {
    if (!self.has_deleted) {
        const i = self.max_id;
        self.alive.set(self.max_id);
        self.max_id += 1;
        return Entity{.index=i, .generation=self.generation.items[i]};
    } else {
        var check: u16 = 0;
        var found = false;
        while (!found) : (check += 1) {
            if (check == MAX_ENTITIES) {
                // TODO add check to only run this when in safe compile modes.
                @panic("Max entity count reached!");
            }
            if (!self.alive.isSet(check)) {
                var in_killed = false;
                // .any(fn) would reduce this by a lot, but I'm not sure if that's possible
                // didn't find that in std.mem
                for (self.killed.items) |k| {
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
        self.alive.set(check);
        if (check >= self.max_id) {
            self.max_id = check;
            self.has_deleted = false;
        }
        return Entity{.index=check, .generation=self.generation.items[check]};
    }
}

/// Checks if the `Entity` is still alive.
/// Returns true if it is alive.
/// Returns false if it has been killed.
pub fn is_alive(self: *@This(), entity: Entity) bool {
    return self.alive.isSet(entity.index) and self.generation.items[entity.index] == entity.generation;
}

/// Kill an entity.
pub fn kill(self: *@This(), entity: Entity) !void {
    if (self.is_alive(entity)) {
        self.alive.unset(entity.index);
        self.generation.items[entity.index] += 1;
        try self.killed.append(entity);
        self.has_deleted = true;
    }
}

/// Clears the killed entity list.
pub fn clear_killed(self: *@This()) void {
    self.killed.items.len = 0;
}

/// Deallocates an Entities struct.
pub fn deinit(self: *@This()) void {
    self.generation.deinit();
    self.killed.deinit();
}

test "Create entity" {
    var entities = try @This().init(std.testing.allocator);
    defer entities.deinit();
    const entity1 = entities.create();
    try expect(entity1.index == 0);
    try expect(entity1.generation == 0);
    try expect(entities.alive.isSet(0));
    try expect(!entities.alive.isSet(1));
    const entity2 = entities.create();
    try expect(entity2.index == 1);
    try expect(entity2.generation == 0);
    try expect(entities.alive.isSet(0));
    try expect(entities.alive.isSet(1));
}

test "Kill create entity" {
    var entities = try @This().init(std.testing.allocator);
    defer entities.deinit();
    const entity1 = entities.create();
    try expect(entity1.index == 0);
    try expect(entity1.generation == 0);
    try expect(entities.alive.isSet(0));
    try expect(!entities.alive.isSet(1));
    try expect(!entities.has_deleted);
    try entities.kill(entity1);
    try expect(entities.has_deleted);
    const entity2 = entities.create();
    try expect(entity2.index == 1);
    try expect(entity2.generation == 0);
    try expect(!entities.alive.isSet(0));
    try expect(entities.alive.isSet(1));
    // This did go all the way to the end to create the entity, so has_deleted should go back to false.
    try expect(!entities.has_deleted);

    entities.clear_killed();

    // has_deleted is false, so we won't try to reuse index 0
    // let's turn has_deleted back to true manually and check if we reuse index 0.
    entities.has_deleted = true;

    const entity3 = entities.create();
    try expect(entity3.index == 0);
    try expect(entity3.generation == 1);
    try expect(entities.alive.isSet(0));
    try expect(entities.alive.isSet(1));
    try expect(!entities.alive.isSet(2));
    try expect(!entities.alive.isSet(3));
    // has_deleted stays to true since we didn't check until the end of the array
    try expect(entities.has_deleted);
    const entity4 = entities.create();
    try expect(entity4.index == 2);
    try expect(entity4.generation == 0);
    try expect(entities.alive.isSet(0));
    try expect(entities.alive.isSet(1));
    try expect(entities.alive.isSet(2));
    try expect(!entities.alive.isSet(3));
    // has_deleted turns back to false
    try expect(!entities.has_deleted);
}

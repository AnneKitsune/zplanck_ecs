const std = @import("std");
const Entity = @import("./Entity.zig");
const Entities = @import("./Entities.zig");
const testing = std.testing;
const alloc = testing.allocator;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "Create Entity" {
    const ent = Entity {.index=0, .generation=0};
}

test "Access entity data" {
    const ent = Entity {.index=1, .generation=0};
    testing.expect(ent.index == 1);
    const ent2 = Entity {.index=2, .generation=0};
    testing.expect(ent2.index == 2);
    testing.expect(ent.index == 1);
}

test "basic add functionality" {
    testing.expect(add(3, 7) == 10);
}

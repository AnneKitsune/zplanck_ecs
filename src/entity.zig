const std = @import("std");

/// An entity index.
/// They are created using the `Entities` struct.
/// They are used as indices with `Components` structs.
///
/// Entities are conceptual "things" which possess attributes (Components).
/// As an exemple, a Car (Entity) has a Color (Component), a Position
/// (Component) and a Speed (Component).
pub const Entity = struct {
    index: u32,
    generation: u32,
};

test "Access entity data" {
    const ent = Entity{ .index = 1, .generation = 0 };
    try std.testing.expect(ent.index == 1);
    const ent2 = Entity{ .index = 2, .generation = 0 };
    try std.testing.expect(ent2.index == 2);
    try std.testing.expect(ent.index == 1);
}

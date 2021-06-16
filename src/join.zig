const std = @import("std");
const Components = @import("./components.zig").Components;
const Entities = @import("./entities.zig");
const Bitset = std.packed_int_array.PackedIntArray(u1, MAX_ENTITIES);
const MAX_ENTITIES=65535;

pub fn Iter(comptime input_types: type) type {
    comptime const outer_types = anytypeToTypes(in_types);
    comptime const inner_types = extractInnerTypes(outer_types);
    return struct {
        bitset: Bitset = undefined,
        args: in_types = undefined,
        current_position: usize = 0,
        max_id: usize = undefined,
        // The tuple or anon list here should use the inner types extracted from the out_type arg.
        // Components(T) -> T
        // Entities -> Entity
        //pub fn next(self: *@This()) ?std.meta.Tuple(&[_]type) {
        //pub fn next(self: *@This()) ?types {
        pub fn next(self: *@This()) ?std.meta.Tuple(&inner_types) {
            return null;
        }

        pub fn init(self: *@This(), in_args: outer_types) void {
            const max_id = 29034234;
            self.bitset = Bitset.initAllTo(0);
            self.args = in_args;
            self.max_id = max_id;
        }
    };
}


// Need to convert from anytype into a list of inner types
// anytype -> []type
fn anytypeToTypes(comptime args: anytype) [std.meta.fields(args).len]type {
    comptime var types: [std.meta.fields(args).len]type = undefined;
    inline for (std.meta.fields(args)) |arg, i| {
        types[i] = arg.field_type;
    }
    //std.meta.fields(@TypeOf(@typeInfo(args)))
    return types;
}

// []type -> []type
// Component(T) -> T
// Entities -> Entity
// _ -> compile error
fn extractInnerTypes(comptime args: []type) [std.meta.fields(args).len]type {
    comptime var types: [std.meta.fields(args).len]type = undefined;
    inline for (std.meta.fields(args)) |arg, i| {
        types[i] = arg.field_type;
    }
    //std.meta.fields(@TypeOf(@typeInfo(args)))
    return types;
}

// then, we have join which takes bitset_ops, args: anytype and returns an iterator over []type data.

/// let iter = join(.{comps1, comps2, comps3}, "1 and (2 or 3)")
pub fn join(comptime bitset_ops: []const u8, args: anytype) Iter(@TypeOf(args)) {
    //const len = args.len;
    ////comptime var types = 
    //inline for (args) |arg| {

    //}
    return .{};
}

test "simple join" {
    var comps1 = try Components(u32).init(std.testing.allocator);
    defer comps1.deinit();
    var comps2 = try Components(u33).init(std.testing.allocator);
    defer comps2.deinit();
    var comps3 = try Components(u34).init(std.testing.allocator);
    defer comps3.deinit();

    var iter = join("1 and (2 or 3)", .{comps1, comps2, comps3});
    while (iter.next()) |tuple| {
        // tuple is of type (?*u32, ?*u33, ?*u34)
    }
    //f(tmp);
    //for (join_and(comps1, comps2)) |(c1, c2)| {
    //}
}

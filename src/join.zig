const std = @import("std");
const Components = @import("components.zig").Components;
const Entity = @import("entity.zig").Entity;
const Entities = @import("entities.zig");
const MAX_ENTITIES = @import("./main.zig").MAX_ENTITIES;
const Bitset = std.bit_set.StaticBitSet(MAX_ENTITIES);

const builtin = @import("builtin");
const benchmark = @import("zig_benchmark");

/// Creates an iterator over the values of the provided argument pointers tuple.
/// The argument must be a tuple containing pointers (const or not) to a struct which
/// provides the following elements or operations:
/// - A field bitset: std.bit_set.StaticBitSet
/// - A function get(u32) -> ?*const T
/// - A function getMut(u32) -> ?*T
/// There is an exception to those rules: if the type is `Entities`, the get function will
/// return *const Entity (not an option (?T)).
pub fn join(elems: anytype) Iter(@TypeOf(elems)) {
    var bitset = elems.@"0".*.bitset;
    var next_id = std.math.inf_u32;

    inline for (std.meta.fields(@TypeOf(elems))) |field| {
        if (!std.mem.eql(u8, field.name, "0")) {
            bitset.setIntersection(@field(elems, field.name).bitset);
        }
        const cur_next_id = @field(elems, field.name).next_id;
        next_id = std.math.min(next_id, cur_next_id);
    }

    const one_count = @intCast(u32, bitset.count());
    return Iter(@TypeOf(elems)){
        .bitset = bitset,
        .inputs = elems,
        .one_count = one_count,
    };
}

pub fn Iter(comptime input_types: type) type {
    return struct {
        bitset: Bitset = undefined,
        inputs: input_types,
        one_count: u32,
        one_found: u32 = 0,
        current_position: u32 = 0,

        // The tuple or anon list here should use the inner types extracted from the out_type arg.
        // Components(T) -> T
        // Entities -> Entity
        pub fn next(this: *@This()) ?extractInnerTypes(input_types) {
            @setRuntimeSafety(false);
            if (this.one_found >= this.one_count) {
                return null;
            }
            while (!this.bitset.isSet(this.current_position)) {
                this.current_position += 1;
            }

            var ret: extractInnerTypes(input_types) = undefined;

            inline for (std.meta.fields(@TypeOf(this.inputs))) |field| {
                if (@typeInfo(field.field_type).Pointer.is_const) {
                    @field(ret, field.name) = @field(this.inputs, field.name).get(this.current_position) orelse @panic("Iterated over a storage which doesn't have the requested index. The calculated iteration bitset must be wrong.");
                } else {
                    @field(ret, field.name) = @field(this.inputs, field.name).getMut(this.current_position) orelse @panic("Iterated over a storage which doesn't have the requested index. The calculated iteration bitset must be wrong.");
                }
            }

            // Needed in case we return, because it wouldn't increase the outer
            // current_position.
            this.current_position += 1;
            this.one_found += 1;
            return ret;
        }
    };
}

/// Converts a type which is tuple of pointers to containers into a tuple of the
/// internal types of those containers.
/// .{*Entities, *Components(u32)} -> .{Entity, u32}
fn extractInnerTypes(comptime args: type) type {
    const args_info = @typeInfo(args);
    if (args_info != .Struct or !args_info.Struct.is_tuple) {
        @compileError("Argument must be a tuple.");
    }

    var types: [std.meta.fields(args).len]type = undefined;
    inline for (std.meta.fields(args)) |arg, i| {
        const arg_info = @typeInfo(arg.field_type);
        if (arg_info != .Pointer) {
            @compileError("Elements inside of the tuple must be pointers.");
        }
        const child = arg_info.Pointer.child;
        const typename = @typeName(child);
        const typename_len = typename.len;
        const child_info = @typeInfo(child);

        if (child_info != .Struct) {
            @compileError("Elements pointed to inside of the tuple must be structs.");
        }

        types[i] = getInnerType(child_info, arg_info, typename_len, typename);
    }
    const tuple = std.meta.Tuple(&types);
    return tuple;
}

fn getInnerType(
    comptime child_info: std.builtin.TypeInfo,
    comptime ptr_info: std.builtin.TypeInfo,
    comptime typename_len: u32,
    comptime typename: *const [typename_len:0]u8,
) type {
    inline for (child_info.Struct.decls) |decl| {
        if (std.mem.eql(u8, decl.name, "InnerType")) {
            if (std.mem.eql(u8, typename, "entities")) {
                return decl.data.Type;
            } else {
                comptime var ret_type = std.builtin.TypeInfo{
                    .Pointer = std.builtin.TypeInfo.Pointer{
                        .size = .One,
                        .is_const = ptr_info.Pointer.is_const,
                        .is_volatile = ptr_info.Pointer.is_volatile,
                        .alignment = @alignOf(decl.data.Type),
                        .child = decl.data.Type,
                        .is_allowzero = ptr_info.Pointer.is_allowzero,
                        .sentinel = ptr_info.Pointer.sentinel,
                        .address_space = ptr_info.Pointer.address_space,
                        //.sentinel = ?decl.data.Type,
                    },
                };
                return @Type(ret_type);
            }
        }
    }
    @compileError("Failed to find InnerType: type inside of the provided type.");
}

test "extract inner types" {
    const MyStruct = struct {
        const InnerType = u32;
    };
    const my_struct = MyStruct{};
    _ = extractInnerTypes(@TypeOf(.{&my_struct}));
}

test "Iter Entities" {
    var entities = try Entities.init(std.testing.allocator);
    defer entities.deinit();

    _ = entities.create();
    _ = entities.create();
    _ = entities.create();
    _ = entities.create();

    const entities_ptr: *const Entities = &entities;

    var count = @as(u32, 0);
    var iter = join(.{entities_ptr});
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expect(count == 4);
}

test "simple join" {
    var comps1 = try Components(u32).init(std.testing.allocator);
    defer comps1.deinit();
    var comps2 = try Components(u33).init(std.testing.allocator);
    defer comps2.deinit();
    var comps3 = try Components(u34).init(std.testing.allocator);
    defer comps3.deinit();

    _ = try comps1.insert(Entity{ .index = 0, .generation = 0 }, 0);
    _ = try comps1.insert(Entity{ .index = 1, .generation = 0 }, 1);
    _ = try comps2.insert(Entity{ .index = 1, .generation = 0 }, 2);
    _ = try comps3.insert(Entity{ .index = 1, .generation = 0 }, 3);

    const comps2_ptr: *const Components(u33) = &comps2;

    var count = @as(u32, 0);
    var iter = join(.{ &comps1, comps2_ptr, &comps3 });
    while (iter.next()) |tuple| {
        count += 1;
        try std.testing.expect(tuple.@"0".* == 1);
        try std.testing.expect(tuple.@"1".* == 2);
        try std.testing.expect(tuple.@"2".* == 3);
    }
    try std.testing.expect(count == 1);
}

test "Benchmark Join" {
    const b = struct {
        fn bench(ctx: *benchmark.Context) void {
            const A = struct {
                v: f32,
            };
            const B = struct {
                v: f32,
            };

            var entities = Entities.init(std.testing.allocator) catch unreachable;
            defer entities.deinit();
            var a = Components(A).init(std.testing.allocator) catch unreachable;
            defer a.deinit();
            var b = Components(B).init(std.testing.allocator) catch unreachable;
            defer b.deinit();

            var count = @as(u32, 0);
            while (count < 10000) : (count += 1) {
                const e = entities.create();
                _ = a.insert(e, A{ .v = 1.0 }) catch unreachable;
                _ = b.insert(e, B{ .v = 1.0 }) catch unreachable;
            }

            const b_ptr: *const Components(B) = &b;

            while (ctx.run()) {
                _ = join(.{ &a, b_ptr });
            }
        }
    }.bench;
    benchmark.benchmark("join", b);
}

fn benchIterSpeed(ctx: *benchmark.Context) void {
    const A = struct {
        v: f32,
    };
    const B = struct {
        v: f32,
    };
    var alloc = std.testing.allocator;
    //var alloc = std.heap.c_allocator;

    var entities = Entities.init(alloc) catch unreachable;
    defer entities.deinit();
    var a = Components(A).init(alloc) catch unreachable;
    defer a.deinit();
    var b = Components(B).init(alloc) catch unreachable;
    defer b.deinit();

    var count = @as(u32, 0);
    while (count < 10000) : (count += 1) {
        const e = entities.create();
        _ = a.insert(e, A{ .v = 1.0 }) catch unreachable;
        _ = b.insert(e, B{ .v = 1.0 }) catch unreachable;
    }

    const b_ptr: *const Components(B) = &b;

    while (ctx.run()) {
        var iter = join(.{ &a, b_ptr });
        while (iter.next()) |tuple| {
            //var ptr1 = tuple.@"0";
            //const ptr2 = tuple.@"1";
            //ptr1.v += ptr2.v;
            tuple.@"0".*.v += tuple.@"1".*.v;
        }
    }
}
test "Benchmark Join Iter Speed" {
    benchmark.benchmark("join iter speed", benchIterSpeed);
}

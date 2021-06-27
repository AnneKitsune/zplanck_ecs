const std = @import("std");
const Components = @import("components.zig").Components;
const Entity = @import("Entity.zig");
const Entities = @import("Entities.zig");
const Bitset = std.bit_set.StaticBitSet(MAX_ENTITIES);
// TODO move MAX_ENTITIES to extern conf
const MAX_ENTITIES=65535;

const benchmark = @import("./deps/zig-benchmark/bench.zig");

pub fn join(elems: anytype) Iter(@TypeOf(elems)) {
    var bitset = elems.@"0".*.bitset;
    var max_id = std.math.inf_u32;

    inline for (std.meta.fields(@TypeOf(elems))) |field| {
        if (!std.mem.eql(u8, field.name, "0")) {
            bitset.setIntersection(@field(elems, field.name).bitset);
        }
        const cur_max_id = @field(elems, field.name).max_id;
        max_id = std.math.min(max_id, cur_max_id);
    }

    return Iter(@TypeOf(elems)) {
        .bitset = bitset,
        .inputs = elems,
        .max_id = max_id,
    };
}

pub fn Iter(comptime input_types: type) type {
    return struct {
        bitset: Bitset = undefined,
        inputs: input_types,
        max_id: u32,
        current_position: u32 = 0,

        // The tuple or anon list here should use the inner types extracted from the out_type arg.
        // Components(T) -> T
        // Entities -> Entity
        pub fn next(this: *@This()) ?extractInnerTypes(input_types) {
            // TODO ensure that max_id is always one more than the max_id in components.
            // TODO rename max_id to "next_id"
            while (!this.bitset.isSet(this.current_position) and this.current_position < this.max_id) {
                this.current_position += 1;
            }
            if (this.current_position < this.max_id) {
                var ret: extractInnerTypes(input_types) = undefined;

                inline for (std.meta.fields(@TypeOf(this.inputs))) |field| {
                    if (@typeInfo(field.field_type).Pointer.is_const) {
                        @field(ret, field.name) = @field(this.inputs, field.name).get(this.current_position)
                                orelse @panic("Iterated over a storage which doesn't have the requested index. The calculated iteration bitset must be wrong.");
                    } else {
                        @field(ret, field.name) = @field(this.inputs, field.name).getMut(this.current_position)
                                orelse @panic("Iterated over a storage which doesn't have the requested index. The calculated iteration bitset must be wrong.");
                    }
                }

                // Needed in case we return, because it wouldn't increase the outer
                // current_position.
                this.current_position += 1;
                return ret;
            } else {
                this.current_position += 1;
                return null;
            }
        }
    };
}


/// Converts a type which is tuple of pointers to containers into a tuple of the
/// internal types of those containers.
/// .{*Entities, *Components(u32)} -> .{Entity, u32}
fn extractInnerTypes(comptime args: type) type {
    comptime const args_info = @typeInfo(args);
    if (args_info != .Struct or !args_info.Struct.is_tuple) {
        @compileError("Argument must be a tuple.");
    }

    comptime var types: [std.meta.fields(args).len]type = undefined;
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
    comptime const tuple = std.meta.Tuple(&types);
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
            if (std.mem.eql(u8, typename, "Entities")) {
                 return decl.data.Type;
            } else {
                comptime var ret_type = std.builtin.TypeInfo {
                    .Pointer = std.builtin.TypeInfo.Pointer {
                        .size = .One,
                        .is_const = ptr_info.Pointer.is_const,
                        .is_volatile = ptr_info.Pointer.is_volatile,
                        .alignment = @alignOf(decl.data.Type),
                        .child = decl.data.Type,
                        .is_allowzero = ptr_info.Pointer.is_allowzero,
                        .sentinel = ptr_info.Pointer.sentinel,
                        //.sentinel = ?decl.data.Type,
                    }
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
    const new_types = extractInnerTypes(@TypeOf(.{&my_struct}));
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
    while (iter.next()) |e| {
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

    _ = try comps1.insert(Entity{.index=0, .generation=0}, 0);
    _ = try comps1.insert(Entity{.index=1, .generation=0}, 1);
    _ = try comps2.insert(Entity{.index=1, .generation=0}, 2);
    _ = try comps3.insert(Entity{.index=1, .generation=0}, 3);

    const comps2_ptr: *const Components(u33) = &comps2;

    var count = @as(u32, 0);
    var iter = join(.{&comps1, comps2_ptr, &comps3});
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
                _ = a.insert(e, A{.v = 1.0}) catch unreachable;
                _ = b.insert(e, B{.v = 1.0}) catch unreachable;
            }

            const b_ptr: *const Components(B) = &b;

            while (ctx.run()) {
                var iter = join(.{&a, b_ptr});
            }
        }}.bench;
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
        _ = a.insert(e, A{.v = 1.0}) catch unreachable;
        _ = b.insert(e, B{.v = 1.0}) catch unreachable;
    }

    const b_ptr: *const Components(B) = &b;

    while (ctx.run()) {
        var iter = join(.{&a, b_ptr});
        while (iter.next()) |tuple| {
            var ptr1 = tuple.@"0";
            const ptr2 = tuple.@"1";
            ptr1.v += ptr2.v;
            //tuple.@"0".*.v += tuple.@"1".*.v;
        }
    }
}
test "Benchmark Join Iter Speed" {
    benchmark.benchmark("join iter speed", benchIterSpeed);
}

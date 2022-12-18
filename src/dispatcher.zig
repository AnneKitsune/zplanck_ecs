const std = @import("std");
const benchmark = @import("zig_benchmark");

const testing = std.testing;

/// Holds a list of systems that can be executed sequentially or in parallel.
/// Parallel execution requires async to be activated, either through
/// - zig test --test-evented-io
/// or by adding `pub const io_mode = .evented` at the top level of your crate.
pub fn Dispatcher(comptime T: type) type {
    return struct {
        systems: T,

        /// Runs all systems sequentially using data from the provided world.
        /// References to data matching the type of the system arguments are
        /// automatically made when calling the system.
        /// Any error will abort the execution and return it.
        pub fn runSeq(this: *const @This(), world: anytype) !void {
            inline for (this.systems) |sys| {
                try callSystem(world, sys);
            }
        }

        //fn runPar(this: *@This(), world: anytype) !void {
        //    // TODO system locking mechanism
        //    inline for (this.systems) |sys| {
        //        //try await callSystem(world, sys);
        //        //try this.loop.runDetached(alloc, callSystemUnwrap, .{world, sys});
        //    }
        //    // this.loop.yield();
        //}
    };
}

fn callSystemUnwrap(world: anytype, system: anytype) void {
    callSystem(world, system) orelse @panic("Call system panicked!");
}

/// Calls a system using the provided world's data.
/// Arguments of the system will be references to the world's fields during execution.
///
/// World should be a pointer to the world.
/// System should be a function. All arguments of this function should be pointers.
///
/// Generics cannot be used. For this, create a wrapping generic struct that will create
/// a concrete function.
pub fn callSystem(world: anytype, system: anytype) !void {
    const fn_info = @typeInfo(@TypeOf(system));

    // check that the input is a function.
    if (fn_info != .Fn) {
        @compileError("System must be a function.");
    }

    // get the ptr types of all the system args.
    comptime var types: [fn_info.Fn.args.len]type = undefined;
    inline for (fn_info.Fn.args) |arg, i| {
        const arg_type = arg.arg_type orelse @compileError("Argument has no type, are you using a generic?");
        const arg_info = @typeInfo(arg_type);
        if (arg_info != .Pointer) {
            @compileError("System arguments must be pointers.");
        }
        types[i] = arg_info.Pointer.child;
    }

    var world_pointers: std.meta.ArgsTuple(@TypeOf(system)) = undefined;
    inline for (types) |t, i| {
        // returns a pointer to a field of type t in world.
        const new_ptr = pointer_to_struct_type(t, world) orelse @panic("Provided world misses a field of the following type that the system requires: " ++ @typeName(t));
        world_pointers[i] = new_ptr;
    }

    try @call(.auto, system, world_pointers);
}

/// Returns a pointer to the first field of the provided runtime structure that has
/// the type Target, if any.
/// The structure should be a pointer to a struct.
fn pointer_to_struct_type(comptime Target: type, structure: anytype) ?*Target {
    //comptime const ptr_info = @typeInfo(@TypeOf(structure));
    //if (ptr_info != .Pointer) {
    //    @compileError("Expected a pointer to a struct.");
    //}

    //comptime const struct_info = @typeInfo(ptr_info.Pointer.child);
    const struct_info = @typeInfo(@TypeOf(structure.*));
    if (struct_info != .Struct) {
        @compileError("Expected a struct.");
    }

    inline for (struct_info.Struct.fields) |field| {
        if (field.field_type == Target) {
            return &@field(structure.*, field.name);
        }
    }
    return null;
}

fn bench_system(_: *u32, _: *const i32) !void {}
fn test_system(a: *u32, _: *const i32) !void {
    a.* = 5;
}
fn test_system2(a: *u32) !void {
    a.* += 1;
}

fn TestGeneric(comptime T: type) type {
    return struct {
        fn test_generic(_: *T) !void {}
    };
}

test "Basic system call from world data" {
    const MyWorld = struct {
        test_a: u32 = 0,
        test_b: i32 = 0,
    };

    var world = MyWorld{};

    try callSystem(&world, test_system);

    try std.testing.expect(world.test_a == 5);
}

test "Basic generic system" {
    const MyWorld = struct {
        test_a: u32 = 0,
        test_b: i32 = 0,
    };

    var world = MyWorld{};

    try callSystem(&world, TestGeneric(u32).test_generic);
}

test "Bench medium system" {
    const b = struct {
        fn bench(ctx: *benchmark.Context) void {
            const MyWorld = struct {
                test_a: u32 = 0,
                test_b: i32 = 0,
            };

            var world = MyWorld{};

            while (ctx.runExplicitTiming()) {
                ctx.startTimer();
                try callSystem(&world, bench_system);
                ctx.stopTimer();
            }
        }
    }.bench;
    benchmark.benchmark("medium system", b);
}

test "Dispatcher run" {
    if (@import("builtin").single_threaded) return error.SkipZigTest;
    if (!std.io.is_async) return error.SkipZigTest;
    const MyWorld = struct {
        test_a: u32 = 0,
        test_b: i32 = 0,
    };

    var world = MyWorld{};

    const systems = .{ test_system, test_system2 };
    var dispatcher = Dispatcher(@TypeOf(systems)){
        .systems = systems,
    };
    try dispatcher.runSeq(&world);
}

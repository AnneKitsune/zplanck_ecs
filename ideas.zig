const MyWorld = struct {
    entities: Entities,
    positions: Components(Position),
    players: Components(Player),
    my_resource: MyResource,
    late_init_resource: ?MyLateInitResource,
};

fn my_system(entities: *Entities,
    positions: *Components(Position),
    players: *const Components(Player),
) !void {
    for (join(positions, players)) |[position, player], _| {
        // returns tuples of pointers inside of the array lists
    }
}

fn main() {
    var world = MyWorld {
        ... init your shit
    };

    const entity1 = world.entities.create();
    world.positions.insert(entity1, Position {
        x = 4,
        y = 2,
        z = 6,
    };

    const dispatcher = Dispatcher(MyWorld);
    dispatcher.callSystem(&world, my_system);
}

// built-in the library
pub fn Dispatcher(comptime WorldType: type) type {
    return struct {

        fn callSystem(world: *World, system: anytype) !void {
            if (typeof system != fn) {
                abort;
            }
            for (system.arguments) |arg, _| {
                if (arg != pointer || arg != const ptr) {
                    abort;
                }
            }

            comptime var call_ptrs = [system.arg_counts; null];
            for (system.arguments) |arg, _| {
                call_ptrs.push(findPtrToFieldInsideOfWorldWithType(typeof arg));
            }

            system.call(call_ptrs);
        }
    };
}


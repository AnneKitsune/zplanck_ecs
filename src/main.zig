const std = @import("std");
const Entity = @import("./Entity.zig");
const Entities = @import("./Entities.zig");
const Components = @import("./components.zig").Components;
const Dispatcher = @import("./dispatcher.zig").Dispatcher;
const join = @import("./join.zig").join;

// Enable evented io to support async functions.
pub const io_mode = .evented;

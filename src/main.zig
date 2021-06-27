const std = @import("std");

pub const Entity = @import("./Entity.zig");
pub const Entities = @import("./Entities.zig");
pub const Components = @import("./components.zig").Components;
pub const Dispatcher = @import("./dispatcher.zig").Dispatcher;
pub const join = @import("./join.zig").join;

const root = @import("root");
pub const MAX_ENTITIES = if(@hasDecl(root, "MAX_ENTITIES")) root.MAX_ENTITIES else 65535;

// Enable evented io to support async functions.
pub const io_mode = .evented;

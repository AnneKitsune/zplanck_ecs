const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zplanck_ecs", "src/main.zig");
    lib.setBuildMode(mode);
    @import("deps.zig").addAll(lib);
    lib.install();

    const test_step = b.step("test", "Run library tests");
    var tests: []const []const u8 = &.{
        "src/entities.zig",
        "src/entity.zig",
        "src/components.zig",
        "src/join.zig",
        "src/dispatcher.zig",
    };
    for (tests) |name| {
        var t = b.addTest(name);
        t.test_evented_io = true;
        t.setBuildMode(mode);
        @import("deps.zig").addAll(t);
        test_step.dependOn(&t.step);
    }
}

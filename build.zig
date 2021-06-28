const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zplanck_ecs", "src/main.zig");
    lib.setBuildMode(mode);

    const pkgs = @import("deps.zig").pkgs;
    pkgs.addAllTo(lib);

    lib.install();


    const test_step = b.step("test", "Run library tests");
    var tests: []const []const u8 = &.{
        "src/Entities.zig",
        "src/Entity.zig",
        "src/components.zig",
        "src/join.zig",
        "src/dispatcher.zig",
    };
    for (tests) |name| {
        var t = b.addTest(name);
        t.test_evented_io = true;
        t.setBuildMode(mode);
        pkgs.addAllTo(t);
        test_step.dependOn(&t.step);
    }
    //var entities_tests = b.addTest("src/Entities.zig");
    //entities_tests.test_evented_io = true;
    //entities_tests.setBuildMode(mode);
    //var entity_tests = b.addTest("src/Entity.zig");
    //entity_tests.test_evented_io = true;
    //entity_tests.setBuildMode(mode);
    //var components_test = b.addTest("src/components.zig");
    //components_test.test_evented_io = true;
    //components_test.setBuildMode(mode);
    //var join_test = b.addTest("src/join.zig");
    //join_test.test_evented_io = true;
    //join_test.setBuildMode(mode);
    //var dispatcher_tests = b.addTest("src/dispatcher.zig");
    //dispatcher_tests.test_evented_io = true;
    //dispatcher_tests.setBuildMode(mode);

    //test_step.dependOn(&entities_tests.step);
    //test_step.dependOn(&entity_tests.step);
    //test_step.dependOn(&components_test.step);
    //test_step.dependOn(&join_test.step);
    //test_step.dependOn(&dispatcher_tests.step);
}

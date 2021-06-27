const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zplanck_ecs", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var entities_tests = b.addTest("src/Entities.zig");
    entities_tests.test_evented_io = true;
    entities_tests.setBuildMode(mode);
    var entity_tests = b.addTest("src/Entity.zig");
    entity_tests.test_evented_io = true;
    entity_tests.setBuildMode(mode);
    var components_test = b.addTest("src/components.zig");
    components_test.test_evented_io = true;
    components_test.setBuildMode(mode);
    var join_test = b.addTest("src/join.zig");
    join_test.test_evented_io = true;
    join_test.setBuildMode(mode);
    var dispatcher_tests = b.addTest("src/dispatcher.zig");
    dispatcher_tests.test_evented_io = true;
    dispatcher_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&entities_tests.step);
    test_step.dependOn(&entity_tests.step);
    test_step.dependOn(&components_test.step);
    test_step.dependOn(&join_test.step);
    test_step.dependOn(&dispatcher_tests.step);
}

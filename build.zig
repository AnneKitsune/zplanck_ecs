const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("entity_component_zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    var entities_tests = b.addTest("src/Entities.zig");
    entities_tests.setBuildMode(mode);
    var components_test = b.addTest("src/components.zig");
    components_test.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&entities_tests.step);
    test_step.dependOn(&components_test.step);
}

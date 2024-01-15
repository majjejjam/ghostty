const std = @import("std");
const NativeTargetInfo = std.zig.system.NativeTargetInfo;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("cimgui", .{
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const imgui = b.dependency("imgui", .{});
    const freetype = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
        .@"enable-libpng" = true,
    });
    const lib = b.addStaticLibrary(.{
        .name = "cimgui",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkLibCpp();
    lib.linkLibrary(freetype.artifact("freetype"));
    if (target.result.os.tag == .windows) {
        lib.linkSystemLibrary("imm32");
    }

    lib.addIncludePath(imgui.path(""));
    module.addIncludePath(.{ .path = "vendor" });

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();
    try flags.appendSlice(&.{
        "-DCIMGUI_FREETYPE=1",
        "-DIMGUI_USE_WCHAR32=1",
        "-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1",
    });
    if (target.result.os.tag == .windows) {
        try flags.appendSlice(&.{
            "-DIMGUI_IMPL_API=extern\t\"C\"\t__declspec(dllexport)",
        });
    } else {
        try flags.appendSlice(&.{
            "-DIMGUI_IMPL_API=extern\t\"C\"",
        });
    }

    lib.addCSourceFile(.{ .file = .{ .path = "vendor/cimgui.cpp" }, .flags = flags.items });
    lib.addCSourceFile(.{ .file = imgui.path("imgui.cpp"), .flags = flags.items });
    lib.addCSourceFile(.{ .file = imgui.path("imgui_draw.cpp"), .flags = flags.items });
    lib.addCSourceFile(.{ .file = imgui.path("imgui_demo.cpp"), .flags = flags.items });
    lib.addCSourceFile(.{ .file = imgui.path("imgui_widgets.cpp"), .flags = flags.items });
    lib.addCSourceFile(.{ .file = imgui.path("imgui_tables.cpp"), .flags = flags.items });
    lib.addCSourceFile(.{ .file = imgui.path("misc/freetype/imgui_freetype.cpp"), .flags = flags.items });

    lib.addCSourceFile(.{
        .file = imgui.path("backends/imgui_impl_opengl3.cpp"),
        .flags = flags.items,
    });

    if (target.result.isDarwin()) {
        if (!target.query.isNative()) {
            try @import("apple_sdk").addPaths(b, &lib.root_module);
            try @import("apple_sdk").addPaths(b, module);
        }
        lib.addCSourceFile(.{
            .file = imgui.path("backends/imgui_impl_metal.mm"),
            .flags = flags.items,
        });
        if (target.result.os.tag == .macos) {
            lib.addCSourceFile(.{
                .file = imgui.path("backends/imgui_impl_osx.mm"),
                .flags = flags.items,
            });
        }
    }

    lib.installHeadersDirectoryOptions(.{
        .source_dir = .{ .path = "vendor" },
        .install_dir = .header,
        .install_subdir = "",
        .include_extensions = &.{".h"},
    });

    b.installArtifact(lib);

    const test_exe = b.addTest(.{
        .name = "test",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    test_exe.linkLibrary(lib);
    const tests_run = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests_run.step);
}

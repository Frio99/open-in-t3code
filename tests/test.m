#import "../src/Launcher.h"
#include <sys/stat.h>

static int passed, failed;
static void check(BOOL ok, const char *name) {
  ok ? passed++ : failed++;
  printf("%s %s\n", ok ? "ok  " : "FAIL", name);
}

static void put(NSString *path, NSString *text) {
  [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
                          withIntermediateDirectories:YES attributes:nil error:nil];
  [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  chmod(path.fileSystemRepresentation, 0755);
}

static NSString *get(NSString *path) {
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc < 2) return 2;
    NSString *t = @(argv[1]);
    NSString *log = [t stringByAppendingPathComponent:@"log"];
    NSString *appPath = [t stringByAppendingPathComponent:@"Any Where/T3 Code (Nightly).app"];
    NSURL *app = [NSURL fileURLWithPath:appPath];
    put([appPath stringByAppendingPathComponent:@"Contents/Info.plist"],
        @"<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>T3 Code (Nightly)</string></dict></plist>");
    put([appPath stringByAppendingPathComponent:@"Contents/MacOS/T3 Code (Nightly)"],
        [NSString stringWithFormat:@"#!/bin/sh\necho \"bundled node=$ELECTRON_RUN_AS_NODE tmp=$TMPDIR cmd=$2 path=[$3]\" > '%@'\n", log]);

    NSString *empty = [t stringByAppendingPathComponent:@"empty"];
    NSString *other = [t stringByAppendingPathComponent:@"other"];
    NSString *good = [t stringByAppendingPathComponent:@"good"];
    NSString *late = [t stringByAppendingPathComponent:@"late"];
    NSString *bad = [t stringByAppendingPathComponent:@"bad"];
    NSString *marker = @"# Written by T3 Code: runs the desktop app's bundled t3 CLI.";

    put([other stringByAppendingPathComponent:@"t3"], [NSString stringWithFormat:@"#!/bin/sh\necho WRONG > '%@'\n", log]);
    put([good stringByAppendingPathComponent:@"t3"],
        [NSString stringWithFormat:@"#!/bin/sh\n%@\necho \"shim cmd=$1 path=[$2]\" > '%@'\n", marker, log]);
    put([late stringByAppendingPathComponent:@"t3"],
        [NSString stringWithFormat:@"#!/bin/sh\n%@\necho x >> '%@/count'\n[ $(wc -l < '%@/count') -ge 4 ] || { echo starting >&2; exit 1; }\n", marker, t, t]);
    put([bad stringByAppendingPathComponent:@"t3"],
        [NSString stringWithFormat:@"#!/bin/sh\n%@\necho 'first line' >&2\necho 'stack' >&2\nexit 1\n", marker]);

    NSString *f = @"/tmp/带 空格/it's & \"quoted\" $(touch nope) `id`";

    check(!OpenFolder(app, f, @[ empty ], 1, 0), "works with no t3 command installed");
    check([get(log) containsString:@"bundled node=1"], "uses the CLI inside the app");
    check([get(log) containsString:[NSString stringWithFormat:@"cmd=app path=[%@]", f]], "special characters arrive untouched");
    check([get(log) containsString:@"tmp=/var/folders/"], "TMPDIR is the per-user temp dir");
    check(!OpenFolder(app, f, @[ other ], 1, 0) && [get(log) hasPrefix:@"bundled"], "ignores an unrelated t3 program");
    check(!OpenFolder(app, f, @[ other, good ], 1, 0) && [get(log) hasPrefix:@"shim cmd=app"], "finds the desktop shim later on the list");
    check([get(log) containsString:[NSString stringWithFormat:@"path=[%@]", f]], "special characters through the shim");
    check(!OpenFolder(app, f, @[ late ], 6, 0.01), "retries while T3 Code starts");
    check([OpenFolder(app, f, @[ bad ], 2, 0.01) isEqualToString:@"first line"], "reports only the first error line");
    check(OpenFolder([NSURL fileURLWithPath:empty], f, @[ empty ], 1, 0) != nil, "broken install gives an error");

    NSString *file = [t stringByAppendingPathComponent:@"file.txt"];
    put(file, @"x");
    NSArray *only = FoldersOnly(@[ [NSURL fileURLWithPath:file], [NSURL fileURLWithPath:t],
                                   [NSURL URLWithString:@"https://example.com"] ]);
    check(only.count == 1 && [only[0] isEqualToString:t], "keeps folders, drops files and links");

    printf("passed=%d failed=%d\n", passed, failed);
    return failed ? 1 : 0;
  }
}

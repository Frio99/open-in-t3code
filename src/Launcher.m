#import "Launcher.h"
#include <unistd.h>

NSString *const T3BundleID = @"com.t3tools.t3code";
static NSString *const ShimMarker = @"Written by T3 Code: runs the desktop app's bundled t3 CLI.";

NSString *L(NSString *zh, NSString *en) {
  return [NSLocale.preferredLanguages.firstObject hasPrefix:@"zh"] ? zh : en;
}

NSURL *FindT3App(void) {
  // Prefer the copy that is running: stable and Nightly share one bundle identifier.
  for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:T3BundleID]) {
    if (app.bundleURL) return app.bundleURL;
  }
  return [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:T3BundleID];
}

NSArray<NSString *> *FoldersOnly(NSArray<NSURL *> *urls) {
  NSMutableArray *folders = [NSMutableArray array];
  for (NSURL *url in urls) {
    BOOL isDir = NO;
    if (url.isFileURL && [NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDir] && isDir) {
      [folders addObject:url.path];
    }
  }
  return folders;
}

NSArray<NSString *> *DefaultBinDirs(void) {
  NSString *home = NSHomeDirectory();
  return @[ [home stringByAppendingPathComponent:@".local/bin"], [home stringByAppendingPathComponent:@"bin"],
            @"/opt/homebrew/bin", @"/usr/local/bin" ];
}

static NSString *FindShim(NSArray<NSString *> *binDirs) {
  for (NSString *dir in binDirs) {
    NSString *path = [dir stringByAppendingPathComponent:@"t3"];
    if (![NSFileManager.defaultManager isExecutableFileAtPath:path]) continue;
    // Other programs are also called t3, and a standalone t3 can be large: read only the header.
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *head = [file readDataOfLength:512];
    [file closeFile];
    if ([head rangeOfData:[ShimMarker dataUsingEncoding:NSUTF8StringEncoding] options:0
                    range:NSMakeRange(0, head.length)].location != NSNotFound) return path;
  }
  return nil;
}

NSTask *MakeT3Task(NSURL *app, NSString *folder, NSArray<NSString *> *binDirs) {
  NSTask *task = [NSTask new];
  NSMutableDictionary *env = [NSProcessInfo.processInfo.environment mutableCopy];
  // t3 finds the desktop app's socket under TMPDIR, which is not guaranteed for launched apps.
  char tmp[PATH_MAX];
  size_t n = confstr(_CS_DARWIN_USER_TEMP_DIR, tmp, sizeof tmp);
  if (n > 0 && n <= sizeof tmp) env[@"TMPDIR"] = @(tmp);

  NSString *shim = FindShim(binDirs);
  if (shim) {
    task.executableURL = [NSURL fileURLWithPath:shim];
    task.arguments = @[ @"app", folder ];
  } else {
    NSString *contents = [app.path stringByAppendingPathComponent:@"Contents"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[contents stringByAppendingPathComponent:@"Info.plist"]];
    NSString *name = info[@"CFBundleExecutable"];
    if (!name) return nil;
    task.executableURL = [NSURL fileURLWithPath:[[contents stringByAppendingPathComponent:@"MacOS"] stringByAppendingPathComponent:name]];
    task.arguments = @[ [contents stringByAppendingPathComponent:@"Resources/app.asar/apps/server/dist/bin.mjs"], @"app", folder ];
    env[@"ELECTRON_RUN_AS_NODE"] = @"1";
  }
  task.environment = env;
  return task;
}

NSString *OpenFolder(NSURL *app, NSString *folder, NSArray<NSString *> *binDirs, int attempts, NSTimeInterval delay) {
  NSString *last = @"";
  for (int i = 0; i < attempts; i++) {
    if (i > 0) [NSThread sleepForTimeInterval:delay];
    NSTask *task = MakeT3Task(app, folder, binDirs);
    if (!task) return L(@"这份 T3 Code 不完整，请重新安装。", @"This copy of T3 Code is incomplete. Please reinstall it.");
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    task.standardInput = NSFileHandle.fileHandleWithNullDevice;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
      last = error.localizedDescription;
      continue;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_global_queue(0, 0), ^{
      if (task.running) [task terminate];
    });
    NSData *out = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    if (task.terminationStatus == 0) return nil;
    NSString *text = [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding] ?: @"";
    last = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            componentsSeparatedByString:@"\n"].firstObject ?: @"";
  }
  return last.length ? last : L(@"T3 Code 没有响应。", @"T3 Code did not respond.");
}

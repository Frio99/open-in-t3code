#import "Launcher.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property BOOL receivedItems;
@property NSUInteger jobs;
@end

@implementation AppDelegate

- (void)showError:(NSString *)title detail:(NSString *)detail {
  [NSApp activateIgnoringOtherApps:YES];
  NSAlert *alert = [NSAlert new];
  alert.messageText = title;
  alert.informativeText = detail;
  [alert runModal];
}

// Returns the folder of the front Finder window, or nil with `code` set.
- (NSString *)frontFolder:(NSInteger *)code {
  NSString *source = @"with timeout of 300 seconds\n"
                      "tell application id \"com.apple.finder\"\n"
                      "if (count of Finder windows) is 0 then error number 9001\n"
                      "return POSIX path of ((target of front Finder window) as alias)\n"
                      "end tell\n"
                      "end timeout";
  NSDictionary *error = nil;
  NSAppleEventDescriptor *result = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
  if (!result) *code = [error[NSAppleScriptErrorNumber] integerValue];
  return result.stringValue;
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
  self.receivedItems = YES;
  NSArray *folders = FoldersOnly(urls);
  if (folders.count) {
    [self open:folders];
    return;
  }
  [self showError:L(@"请拖入文件夹", @"Drop a folder") detail:L(@"不支持单个文件。", @"Individual files are not supported.")];
  if (!self.jobs) [NSApp terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  if (self.receivedItems) return;
  NSInteger code = 0;
  NSString *folder = [self frontFolder:&code];

  // For bug reports and tests: print the folder a click would open, without opening it.
  if ([NSProcessInfo.processInfo.arguments containsObject:@"--print-target"]) {
    printf("%s\n", folder ? folder.UTF8String : [NSString stringWithFormat:@"error %ld", (long)code].UTF8String);
    fflush(stdout);
    [NSApp terminate:nil];
    return;
  }
  if (folder) {
    if (folder.length > 1 && [folder hasSuffix:@"/"]) folder = [folder substringToIndex:folder.length - 1];
    [self open:@[ folder ]];
    return;
  }
  if (code == -1743) {
    [self showError:L(@"需要允许控制访达", @"Finder access is needed")
             detail:L(@"到「系统设置 → 隐私与安全性 → 自动化」，打开 Open in T3 Code 下面的「访达」，再点一次。",
                      @"In System Settings → Privacy & Security → Automation, turn on Finder under Open in T3 Code, then click again.")];
  } else {
    [self showError:L(@"没有可以打开的文件夹", @"No folder to open")
             detail:L(@"先在访达里进入一个文件夹，再点这个按钮。「最近使用」、搜索结果等不是真实文件夹，不能打开。",
                      @"Open a folder in Finder, then click again. Recents and search results are not real folders.")];
  }
  [NSApp terminate:nil];
}

- (void)open:(NSArray<NSString *> *)folders {
  NSURL *app = FindT3App();
  if (!app) {
    [self showError:L(@"没有找到 T3 Code", @"T3 Code was not found")
             detail:L(@"请先安装 T3 Code 桌面版：https://t3.codes/download", @"Install the T3 Code desktop app first: https://t3.codes/download")];
    [NSApp terminate:nil];
    return;
  }
  self.jobs++;
  // Also brings back a running app whose last window was closed.
  [NSWorkspace.sharedWorkspace openApplicationAtURL:app configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:nil];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString *failed = nil, *reason = nil;
    for (NSString *folder in folders) {
      reason = OpenFolder(app, folder, DefaultBinDirs(), 20, 1);
      if (reason) {
        failed = folder;
        break;
      }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      if (failed) {
        [self showError:L(@"没能在 T3 Code 中打开", @"Could not open in T3 Code")
                 detail:[NSString stringWithFormat:@"%@\n\n%@\n\n%@", failed, reason,
                         L(@"请确认 T3 Code 已更新到最新版。", @"Make sure T3 Code is up to date.")]];
      }
      if (--self.jobs == 0) [NSApp terminate:nil];
    });
  });
}

@end

int main(void) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *delegate = [AppDelegate new];
    app.delegate = delegate;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [app run];
  }
  return 0;
}

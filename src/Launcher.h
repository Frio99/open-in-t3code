#import <Cocoa/Cocoa.h>

extern NSString *const T3BundleID;

/// Chinese when the user's first preferred language is Chinese, otherwise English.
NSString *L(NSString *zh, NSString *en);

NSURL *FindT3App(void);
NSArray<NSString *> *FoldersOnly(NSArray<NSURL *> *urls);

/// The desktop app's own `t3` shim when installed (it knows a custom T3 home), else the CLI bundled in the app.
NSTask *MakeT3Task(NSURL *app, NSString *folder, NSArray<NSString *> *binDirs);
NSArray<NSString *> *DefaultBinDirs(void);

/// Retries while T3 Code starts. Returns nil on success, otherwise the last error.
NSString *OpenFolder(NSURL *app, NSString *folder, NSArray<NSString *> *binDirs, int attempts, NSTimeInterval delay);

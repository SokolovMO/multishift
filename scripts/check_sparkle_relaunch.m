// Isolated fixture app: exercises Sparkle's real Install and Relaunch path, never production apps.
#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>

@interface RelaunchCheck : NSObject <NSApplicationDelegate, SPUUserDriver, SPUUpdaterDelegate>
@property(nonatomic, strong) SPUUpdater *updater;
@property(nonatomic, copy) NSString *root;
@end
@implementation RelaunchCheck
- (void)record:(NSString *)event {
    NSString *line = [NSString stringWithFormat:@"%@: pid=%d build=%@\n", event, getpid(), [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:[self.root stringByAppendingPathComponent:@"events.log"]];
    [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile];
}
- (void)fail:(NSString *)message {
    [message writeToFile:[self.root stringByAppendingPathComponent:@"failure.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    fprintf(stderr, "%s\n", message.UTF8String); exit(1);
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.root = [NSBundle.mainBundle objectForInfoDictionaryKey:@"AcceptanceRoot"];
    if (![NSBundle.mainBundle.bundleIdentifier hasPrefix:@"com.multishift.relaunch-test."] || !self.root) exit(2);
    [self record:@"started"];
    if ([[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] isEqual:@"2"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSDictionary *result = @{@"restarted": @YES, @"survived_seconds": @5, @"pid": @(getpid()), @"build": @2};
            NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
            [data writeToFile:[self.root stringByAppendingPathComponent:@"restarted.json"] atomically:YES];
            [self record:@"restart-survived"]; [NSApp terminate:nil];
        });
        return;
    }
    self.updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle applicationBundle:NSBundle.mainBundle userDriver:self delegate:self];
    self.updater.automaticallyChecksForUpdates = NO;
    self.updater.automaticallyDownloadsUpdates = NO;
    NSError *error = nil;
    if (![self.updater startUpdater:&error]) [self fail:error.description];
    [self.updater checkForUpdates];
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender { [self record:@"terminate"]; return NSTerminateNow; }
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SPUUpdater *)updater { return NO; }
- (BOOL)updater:(SPUUpdater *)updater shouldDownloadReleaseNotesForUpdate:(SUAppcastItem *)item { return NO; }
- (void)updater:(SPUUpdater *)updater didAbortWithError:(NSError *)error { [self fail:error.description]; }
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply { [self fail:@"unexpected permission prompt"]; }
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancellation {}
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply { [self record:@"update-found"]; reply(SPUUserUpdateChoiceInstall); }
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error {}
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement { [self fail:error.description]; }
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement { [self fail:error.description]; }
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancellation { [self record:@"downloading"]; }
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate { [self record:@"extracting"]; }
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { [self record:@"install-and-relaunch"]; reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry {}
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))acknowledgement { acknowledgement(); }
- (void)dismissUpdateInstallation {}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyProhibited];
        RelaunchCheck *check = [RelaunchCheck new]; app.delegate = check;
        [app run];
    }
    return 0;
}

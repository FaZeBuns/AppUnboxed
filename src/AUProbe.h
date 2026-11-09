#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs every known way of asking iOS "is this app installed?" against the
/// given bundle ids and returns, per method, which ids it reported. Used to
/// find out which methods a given iOS version still answers for a sandboxed
/// app. `stage` is called with each method's name just before it runs, so a
/// crash inside a private API can be traced to the method that caused it.
NSDictionary<NSString *, id> *AURunDetectionProbes(NSArray<NSString *> *bundleIDs,
                                                   NSArray<NSString *> *schemes,
                                                   void (^stage)(NSString *name));

/// Dynamically discovers installed user applications from LaunchServices plugins
/// (app extensions such as widgets, notification extensions, share extensions, etc.).
/// This private LaunchServices API is NOT blocked by iOS sandboxing and works on
/// stock iOS (tested up to iOS 27.1). Returns an array of dictionaries with keys "id" and "name".
NSArray<NSDictionary<NSString *, NSString *> *> *AUInstalledPluginApps(void);

/// Direct LaunchServices scheme check via -[LSApplicationWorkspace isApplicationAvailableToOpenURL:error:].
/// Unlike UIApplication.shared.canOpenURL, this does NOT enforce the 50-scheme limit
/// from LSApplicationQueriesSchemes.
BOOL AUIsApplicationAvailableToOpenURL(NSURL *url);

/// Opens an application by bundle ID via LaunchServices.
BOOL AUOpenApplicationWithBundleID(NSString *bundleID);

NS_ASSUME_NONNULL_END

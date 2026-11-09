#import "AUProbe.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// Everything here goes through the Objective-C runtime by name, inside
// @try/@catch, so a missing or changed private API reports "unavailable"
// instead of taking the app down.

// Declared so ARC knows this is an init method (it consumes the allocated
// object); calling it through objc_msgSend double-released on failure.
@interface NSObject (AUPrivateInit)
- (instancetype)initWithBundleIdentifier:(NSString *)identifier allowPlaceholder:(BOOL)allow error:(NSError **)error;
@end

static id AUWorkspace(void) {
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
    Class cls = NSClassFromString(@"LSApplicationWorkspace");
    SEL sel = NSSelectorFromString(@"defaultWorkspace");
    if (!cls || ![cls respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls, sel);
}

static NSString *AUBundleID(id obj) {
    for (NSString *name in @[@"bundleIdentifier", @"applicationIdentifier", @"identifier"]) {
        SEL sel = NSSelectorFromString(name);
        if ([obj respondsToSelector:sel]) {
            id v = ((id (*)(id, SEL))objc_msgSend)(obj, sel);
            if ([v isKindOfClass:[NSString class]]) return v;
        }
    }
    return nil;
}

static NSArray<NSString *> *AUIDs(id collection) {
    NSMutableArray *out = [NSMutableArray array];
    if ([collection isKindOfClass:[NSEnumerator class]]) collection = [(NSEnumerator *)collection allObjects];
    if (![collection isKindOfClass:[NSArray class]]) return out;
    for (id item in (NSArray *)collection) {
        NSString *bid = AUBundleID(item);
        if (bid) [out addObject:bid];
        if (out.count >= 1500) break;
    }
    return out;
}

static NSData *AUIconData(NSString *bid, int format) {
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![UIImage respondsToSelector:sel]) return nil;
    UIImage *img = ((UIImage *(*)(id, SEL, NSString *, int, CGFloat))objc_msgSend)([UIImage class], sel, bid, format, 2.0);
    return img ? UIImagePNGRepresentation(img) : nil;
}

NSDictionary<NSString *, id> *AURunDetectionProbes(NSArray<NSString *> *bundleIDs,
                                                   NSArray<NSString *> *schemes,
                                                   void (^stage)(NSString *name)) {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    NSMutableDictionary *errors = [NSMutableDictionary dictionary];
    id ws = AUWorkspace();
    report[@"hasWorkspace"] = @(ws != nil);

// Variadic so commas inside the body do not split the macro arguments.
#define AU_METHOD(NAME, ...) \
    stage(@NAME); \
    @try { __VA_ARGS__ } @catch (NSException *e) { errors[@NAME] = e.reason ?: @"exception"; }

    // 1. Whole-list enumerators.
    AU_METHOD("enum.allInstalledApplications", {
        SEL s = NSSelectorFromString(@"allInstalledApplications");
        if ([ws respondsToSelector:s]) report[@"enum.allInstalledApplications"] = AUIDs(((id (*)(id, SEL))objc_msgSend)(ws, s));
    })
    AU_METHOD("enum.allApplications", {
        SEL s = NSSelectorFromString(@"allApplications");
        if ([ws respondsToSelector:s]) report[@"enum.allApplications"] = AUIDs(((id (*)(id, SEL))objc_msgSend)(ws, s));
    })
    AU_METHOD("enum.applicationsOfType", {
        SEL s = NSSelectorFromString(@"applicationsOfType:");
        if ([ws respondsToSelector:s]) report[@"enum.applicationsOfType"] = AUIDs(((id (*)(id, SEL, NSUInteger))objc_msgSend)(ws, s, 0));
    })
    AU_METHOD("enum.installedPlugins", {
        SEL s = NSSelectorFromString(@"installedPlugins");
        if ([ws respondsToSelector:s]) report[@"enum.installedPlugins"] = AUIDs(((id (*)(id, SEL))objc_msgSend)(ws, s));
    })
    AU_METHOD("enum.applicationRecords", {
        Class rec = NSClassFromString(@"LSApplicationRecord");
        SEL s = NSSelectorFromString(@"enumeratorWithOptions:");
        if (rec && [rec respondsToSelector:s]) {
            report[@"enum.applicationRecords"] = AUIDs(((id (*)(id, SEL, NSUInteger))objc_msgSend)(rec, s, 0));
        }
    })

    // 2. Per-app questions.
    AU_METHOD("id.workspaceIsInstalled", {
        SEL s = NSSelectorFromString(@"applicationIsInstalled:");
        if ([ws respondsToSelector:s]) {
            NSMutableArray *hits = [NSMutableArray array];
            for (NSString *bid in bundleIDs) {
                if (((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws, s, bid)) [hits addObject:bid];
            }
            report[@"id.workspaceIsInstalled"] = hits;
        }
    })
    AU_METHOD("id.proxy", {
        Class cls = NSClassFromString(@"LSApplicationProxy");
        SEL make = NSSelectorFromString(@"applicationProxyForIdentifier:");
        if (cls && [cls respondsToSelector:make]) {
            NSMutableArray *installed = [NSMutableArray array], *named = [NSMutableArray array], *located = [NSMutableArray array];
            SEL sInstalled = NSSelectorFromString(@"isInstalled");
            SEL sName = NSSelectorFromString(@"localizedName");
            SEL sURL = NSSelectorFromString(@"bundleURL");
            for (NSString *bid in bundleIDs) {
                id p = ((id (*)(id, SEL, NSString *))objc_msgSend)(cls, make, bid);
                if (!p) continue;
                if ([p respondsToSelector:sInstalled] && ((BOOL (*)(id, SEL))objc_msgSend)(p, sInstalled)) [installed addObject:bid];
                if ([p respondsToSelector:sName] && ((id (*)(id, SEL))objc_msgSend)(p, sName)) [named addObject:bid];
                if ([p respondsToSelector:sURL] && ((id (*)(id, SEL))objc_msgSend)(p, sURL)) [located addObject:bid];
            }
            report[@"id.proxy.isInstalled"] = installed;
            report[@"id.proxy.hasName"] = named;
            report[@"id.proxy.hasURL"] = located;
        }
    })
    AU_METHOD("id.applicationRecord", {
        Class cls = NSClassFromString(@"LSApplicationRecord");
        SEL s = NSSelectorFromString(@"initWithBundleIdentifier:allowPlaceholder:error:");
        if (cls && [cls instancesRespondToSelector:s]) {
            NSMutableArray *hits = [NSMutableArray array];
            NSMutableDictionary *sampleErrors = [NSMutableDictionary dictionary];
            for (NSString *bid in bundleIDs) {
                NSError *err = nil;
                id rec = [[cls alloc] initWithBundleIdentifier:bid allowPlaceholder:NO error:&err];
                if (rec) [hits addObject:bid];
                else if (err && sampleErrors.count < 4) sampleErrors[bid] = [NSString stringWithFormat:@"%@ %ld", err.domain, (long)err.code];
            }
            report[@"id.applicationRecord"] = hits;
            report[@"id.applicationRecord.errors"] = sampleErrors;
        }
    })
    AU_METHOD("id.icon", {
        for (NSNumber *format in @[@0, @2, @10]) {
            NSData *fake = AUIconData(@"com.appunboxed.none.zz9", format.intValue);
            NSData *fake2 = AUIconData(@"org.nothing.qq7.fake", format.intValue);
            if (!fake || ![fake isEqualToData:fake2]) continue;
            NSMutableArray *hits = [NSMutableArray array];
            for (NSString *bid in bundleIDs) {
                NSData *d = AUIconData(bid, format.intValue);
                if (d && ![d isEqualToData:fake]) [hits addObject:bid];
            }
            report[[NSString stringWithFormat:@"id.icon.format%@", format]] = hits;
        }
    })
    AU_METHOD("id.container", {
        dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
        Class cls = NSClassFromString(@"MCMAppContainer");
        SEL s = NSSelectorFromString(@"containerWithIdentifier:error:");
        if (cls && [cls respondsToSelector:s]) {
            NSMutableArray *hits = [NSMutableArray array];
            for (NSString *bid in bundleIDs) {
                NSError *err = nil;
                if (((id (*)(id, SEL, NSString *, NSError **))objc_msgSend)(cls, s, bid, &err)) [hits addObject:bid];
            }
            report[@"id.container"] = hits;
        }
    })

    // 3. URL schemes, through the routes that are not the public canOpenURL.
    AU_METHOD("scheme.handlers", {
        SEL s = NSSelectorFromString(@"applicationsAvailableForHandlingURLScheme:");
        if ([ws respondsToSelector:s]) {
            NSMutableDictionary *hits = [NSMutableDictionary dictionary];
            for (NSString *scheme in schemes) {
                NSArray *ids = AUIDs(((id (*)(id, SEL, NSString *))objc_msgSend)(ws, s, scheme));
                if (ids.count) hits[scheme] = ids;
            }
            report[@"scheme.handlers"] = hits;
        }
    })
    AU_METHOD("scheme.openers", {
        SEL s = NSSelectorFromString(@"applicationsAvailableForOpeningURL:");
        if ([ws respondsToSelector:s]) {
            NSMutableDictionary *hits = [NSMutableDictionary dictionary];
            for (NSString *scheme in schemes) {
                NSURL *url = [NSURL URLWithString:[scheme stringByAppendingString:@"://"]];
                if (!url) continue;
                NSArray *ids = AUIDs(((id (*)(id, SEL, NSURL *))objc_msgSend)(ws, s, url));
                if (ids.count) hits[scheme] = ids;
            }
            report[@"scheme.openers"] = hits;
        }
    })
    AU_METHOD("scheme.isAvailable", {
        SEL s = NSSelectorFromString(@"isApplicationAvailableToOpenURL:error:");
        if ([ws respondsToSelector:s]) {
            NSMutableArray *hits = [NSMutableArray array];
            for (NSString *scheme in schemes) {
                NSURL *url = [NSURL URLWithString:[scheme stringByAppendingString:@"://"]];
                NSError *err = nil;
                if (url && ((BOOL (*)(id, SEL, NSURL *, NSError **))objc_msgSend)(ws, s, url, &err)) [hits addObject:scheme];
            }
            report[@"scheme.isAvailable"] = hits;
        }
    })

    // 4. Installed app extensions (share sheets, widgets, keyboards...), whose
    //    identifiers give away the app that contains them.
    AU_METHOD("extensions", {
        Class cls = NSClassFromString(@"NSExtension");
        SEL s = NSSelectorFromString(@"extensionsWithMatchingAttributes:error:");
        if (cls && [cls respondsToSelector:s]) {
            NSMutableDictionary *byPoint = [NSMutableDictionary dictionary];
            for (NSString *point in @[@"com.apple.share-services", @"com.apple.ui-services", @"com.apple.widgetkit-extension",
                                      @"com.apple.intents-service", @"com.apple.keyboard-service", @"com.apple.usernotifications.service",
                                      @"com.apple.fileprovider-nonui", @"com.apple.Safari.web-extension", @"com.apple.message-payload-provider"]) {
                NSError *err = nil;
                id found = ((id (*)(id, SEL, NSDictionary *, NSError **))objc_msgSend)(cls, s, @{@"NSExtensionPointName": point}, &err);
                NSArray *ids = AUIDs(found);
                if (ids.count) byPoint[point] = ids;
                else if (err) byPoint[[point stringByAppendingString:@".error"]] = [NSString stringWithFormat:@"%@ %ld", err.domain, (long)err.code];
            }
            report[@"extensions"] = byPoint;
        }
    })

    // 5. SpringBoard's own list, and plain directory listings.
    AU_METHOD("springboard", {
        void *lib = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        CFArrayRef (*fn)(Boolean, Boolean) = lib ? dlsym(lib, "SBSCopyApplicationDisplayIdentifiers") : NULL;
        if (fn) {
            NSArray *ids = CFBridgingRelease(fn(false, false));
            report[@"springboard"] = [ids isKindOfClass:[NSArray class]] ? ids : @[];
        }
    })
    AU_METHOD("directories", {
        NSMutableDictionary *dirs = [NSMutableDictionary dictionary];
        for (NSString *path in @[@"/Applications", @"/var/containers/Bundle/Application", @"/private/var/containers/Bundle/Application",
                                 @"/var/mobile/Containers/Data/Application", @"/var/mobile/Library/SpringBoard"]) {
            NSError *err = nil;
            NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&err];
            dirs[path] = items ? @(items.count) : [NSString stringWithFormat:@"denied %ld", (long)err.code];
        }
        report[@"directories"] = dirs;
    })

#undef AU_METHOD
    stage(@"finished");
    report[@"errors"] = errors;
    report[@"pluginApps"] = AUInstalledPluginApps();
    return report;
}

NSArray<NSDictionary<NSString *, NSString *> *> *AUInstalledPluginApps(void) {
    NSMutableArray *result = [NSMutableArray array];
    @try {
        id ws = AUWorkspace();
        if (!ws) return result;
        SEL sPlugins = NSSelectorFromString(@"installedPlugins");
        if (![ws respondsToSelector:sPlugins]) return result;

        NSArray *plugins = ((id (*)(id, SEL))objc_msgSend)(ws, sPlugins);
        if (![plugins isKindOfClass:[NSArray class]]) return result;

        SEL sContaining = NSSelectorFromString(@"containingBundle");
        SEL sBid = NSSelectorFromString(@"bundleIdentifier");
        SEL sName = NSSelectorFromString(@"localizedName");
        SEL sType = NSSelectorFromString(@"applicationType");

        NSString *ownID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSMutableSet *seen = [NSMutableSet set];

        for (id p in plugins) {
            if (![p respondsToSelector:sContaining]) continue;
            id cb = ((id (*)(id, SEL))objc_msgSend)(p, sContaining);
            if (!cb) continue;

            if ([cb respondsToSelector:sType]) {
                NSString *type = ((id (*)(id, SEL))objc_msgSend)(cb, sType);
                if ([type isKindOfClass:[NSString class]] && ![type isEqualToString:@"User"]) {
                    continue;
                }
            }

            if (![cb respondsToSelector:sBid]) continue;
            NSString *bid = ((id (*)(id, SEL))objc_msgSend)(cb, sBid);
            if (![bid isKindOfClass:[NSString class]] || bid.length == 0) continue;
            if ([bid isEqualToString:ownID] || [ownID hasPrefix:[bid stringByAppendingString:@"."]]) continue;
            if ([seen containsObject:bid]) continue;

            [seen addObject:bid];
            NSString *name = bid;
            if ([cb respondsToSelector:sName]) {
                NSString *locName = ((id (*)(id, SEL))objc_msgSend)(cb, sName);
                if ([locName isKindOfClass:[NSString class]] && locName.length > 0) {
                    name = locName;
                }
            }
            [result addObject:@{ @"id": bid, @"name": name }];
        }
    } @catch (NSException *e) {
        NSLog(@"AUInstalledPluginApps exception: %@", e);
    }
    return result;
}

BOOL AUIsApplicationAvailableToOpenURL(NSURL *url) {
    if (!url) return NO;
    @try {
        id ws = AUWorkspace();
        if (!ws) return NO;
        SEL sel = NSSelectorFromString(@"isApplicationAvailableToOpenURL:error:");
        if (![ws respondsToSelector:sel]) return NO;
        NSError *err = nil;
        return ((BOOL (*)(id, SEL, NSURL *, NSError **))objc_msgSend)(ws, sel, url, &err);
    } @catch (NSException *e) {
        return NO;
    }
}

BOOL AUOpenApplicationWithBundleID(NSString *bundleID) {
    if (!bundleID || bundleID.length == 0) return NO;
    @try {
        id ws = AUWorkspace();
        if (!ws) return NO;
        SEL sel = NSSelectorFromString(@"openApplicationWithBundleID:");
        if ([ws respondsToSelector:sel]) {
            return ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws, sel, bundleID);
        }
    } @catch (NSException *e) {}
    return NO;
}


#import <Foundation/Foundation.h>
#import <Foundation/NSFileManager.h>
#import <sys/snapshot.h>
#import <getopt.h>

typedef char io_string_t[512];
typedef mach_port_t io_object_t;
typedef io_object_t io_registry_entry_t;
io_registry_entry_t IORegistryEntryFromPath(mach_port_t master, const io_string_t path);
CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, uint32_t options);
kern_return_t IOObjectRelease(io_object_t object);

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(NSDictionary *)applicationDictionary;
- (BOOL)registerBundleWithInfo:(NSDictionary *)bundleInfo options:(NSDictionary *)options type:(unsigned long long)arg3 progress:(id)arg4 ;
- (BOOL)registerApplication:(NSURL *)url;
- (BOOL)registerPlugin:(NSURL *)url;
- (BOOL)unregisterApplication:(NSURL *)url;
- (NSArray *)installedPlugins;
-(void)_LSPrivateSyncWithMobileInstallation;
@end

void usage(char *name) {
	printf(
		"Usage: %s [volume] [snapshot]\n", name);
}

NSString *bootsnapshot() {
	NSMutableString *outString = [@"com.apple.os.update-" mutableCopy];
	const UInt8 *bytes;
	CFIndex length;
	CFDataRef manifestHash, rootSnapshotName;

	io_registry_entry_t chosen = IORegistryEntryFromPath(0, "IODeviceTree:/chosen");

	rootSnapshotName = IORegistryEntryCreateCFProperty(chosen, CFSTR("root-snapshot-name"), kCFAllocatorDefault, 0);

	if (rootSnapshotName != NULL && CFGetTypeID(rootSnapshotName) == CFDataGetTypeID()) {
		CFStringRef snapshotString = CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, rootSnapshotName, kCFStringEncodingUTF8);
		CFRelease(rootSnapshotName);
		char buffer[100];
		const char *ptr = CFStringGetCStringPtr(snapshotString, kCFStringEncodingUTF8);
		if (ptr == NULL) {
			if (CFStringGetCString(snapshotString, buffer, 100, kCFStringEncodingUTF8))
				ptr = buffer;
		}
		return [NSString stringWithUTF8String:ptr];
	} else {
		manifestHash = (CFDataRef)IORegistryEntryCreateCFProperty(chosen, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);
		IOObjectRelease(chosen);

		if (manifestHash == NULL || CFGetTypeID(manifestHash) != CFDataGetTypeID()) {
			fprintf(stderr, "Unable to read boot-manifest-hash or root-snapshot-name\n");
			exit(1);
		}

		length = CFDataGetLength(manifestHash);
		bytes = CFDataGetBytePtr(manifestHash);
		CFRelease(manifestHash);

		for (int i = 0; i < length; i++)
			[outString appendFormat:@"%02X", bytes[i]];
	}

	return outString;
}

int restore(const char *vol, const char *snap) {
	int fd = open(vol, O_RDONLY, 0);

	int ret = fs_snapshot_revert(fd, snap, 0);
	return ret;
}

int mount(const char *vol, const char *snap, const char *mnt) {
	int fd = open(vol, O_RDONLY, 0);

	BOOL isDir;
	NSFileManager *fileManager = [NSFileManager defaultManager]; 
		if(![fileManager fileExistsAtPath:[NSString stringWithUTF8String:mnt] isDirectory:&isDir])
			if(![fileManager createDirectoryAtPath:[NSString stringWithUTF8String:mnt] withIntermediateDirectories:YES attributes:nil error:NULL])
				NSLog(@"Error: Create folder failed %s", mnt);

	int ret = fs_snapshot_mount(fd, mnt, snap, 0);

	return ret;
}

NSMutableSet *findApps(const char *root, const char *mnt) {
	NSMutableString *rootApplications = [NSMutableString stringWithUTF8String:root];
	rootApplications = [[rootApplications stringByAppendingString:@"/Applications"] mutableCopy];

	NSMutableString *mntApplications = [NSMutableString stringWithUTF8String:mnt];
	mntApplications = [[mntApplications stringByAppendingString:@"/Applications"] mutableCopy];

	NSArray *rootApps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootApplications error:nil];
	NSArray *mntApps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mntApplications error:nil];

	NSMutableSet *ret = [[NSMutableSet alloc] init];
	for (NSString *app in rootApps) {
		if (![mntApps containsObject:app]) {
			[ret addObject:[@"/Applications/" stringByAppendingString:app]];
		}
	}

	return ret;
}

int unregisterPath(NSString *path) {
	path = [path stringByResolvingSymlinksInPath];
	NSURL *url = [NSURL fileURLWithPath:path];
	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	return [workspace unregisterApplication:url];
}

int rename(const char *vol, const char *snap) {
	int fd = open(vol, O_RDONLY, 0);

	int ret = fs_snapshot_rename(fd, snap, [bootsnapshot() UTF8String], 0);
	return ret;
}

int clean() {
	NSArray *extrafiles = @[@"/var/lib", @"/var/cache"];
	NSError *error = nil;
	for (NSString *path in extrafiles) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:&error];
	}
	return 0;
}

int main(int argc, char *argv[]) {
	if (argc != 3) {
		usage(argv[0]);
		return 0;
	}

	char *vol = argv[1];
	char *snap = argv[2];
	char *mnt = "/tmp/rootfsmnt";

	printf("Restoring snapshot %s...\n", snap);
	restore(vol, snap);
	printf("Restored snapshot...\n");
	printf("Mounting rootfs...\n");
	mount(vol, snap, mnt);
	printf("Mounted %s at %s\n", snap, mnt);
	NSMutableSet *appSet = findApps(vol, mnt);
	if ([appSet count]) {
		for (NSString *app in appSet) {
			printf("unregistering %s\n", [app UTF8String]);
			unregisterPath(app);
		}
	}
	printf("Cleaning up /var\n");
	clean();
	printf("Renaming snapshot...\n");
	rename(vol, snap);
	printf("Restoring %s on %s has succeeded\n", snap, vol); 
	return 0;
}

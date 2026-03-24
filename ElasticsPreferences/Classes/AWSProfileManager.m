//
//  AWSProfileManager.m
//  Elastics
//
//  Resolves AWS credentials from named profiles using the AWS CLI.
//  Supports both static credential profiles and SSO-backed profiles.
//

#import "AWSProfileManager.h"

NSString *const kAWSProfileAccessKeyId     = @"AccessKeyId";
NSString *const kAWSProfileSecretAccessKey = @"SecretAccessKey";
NSString *const kAWSProfileSessionToken    = @"SessionToken";

@implementation AWSProfileManager

+ (NSDictionary *)credentialsForProfile:(NSString *)profileName
{
    if (![profileName length])
        return nil;

    // Find the aws CLI binary
    NSString *awsPath = [self _awsCLIPath];
    if (!awsPath)
        return nil;

    NSTask *task = [[[NSTask alloc] init] autorelease];
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];

    [task setLaunchPath:awsPath];
    [task setArguments:[NSArray arrayWithObjects:
                        @"configure", @"export-credentials",
                        @"--profile", profileName,
                        nil]];
    [task setStandardOutput:outputPipe];
    [task setStandardError:errorPipe];

    // Set HOME so aws CLI can find ~/.aws/
    NSDictionary *env = [NSDictionary dictionaryWithObjectsAndKeys:
                         NSHomeDirectory(), @"HOME",
                         @"/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin", @"PATH",
                         nil];
    [task setEnvironment:env];

    @try {
        [task launch];
        [task waitUntilExit];
    }
    @catch (NSException *exception) {
        NSLog(@"AWSProfileManager: failed to launch aws CLI: %@", exception);
        return nil;
    }

    if ([task terminationStatus] != 0) {
        NSData *errData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        NSString *errString = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];
        NSLog(@"AWSProfileManager: aws CLI returned error for profile '%@': %@", profileName, errString);
        return nil;
    }

    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    if (![outputData length])
        return nil;

    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:outputData options:0 error:&jsonError];
    if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
        NSLog(@"AWSProfileManager: failed to parse JSON response: %@", jsonError);
        return nil;
    }

    NSString *accessKeyId = [json objectForKey:kAWSProfileAccessKeyId];
    NSString *secretAccessKey = [json objectForKey:kAWSProfileSecretAccessKey];

    if (![accessKeyId length] || ![secretAccessKey length]) {
        NSLog(@"AWSProfileManager: credentials missing from response for profile '%@'", profileName);
        return nil;
    }

    NSMutableDictionary *credentials = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        accessKeyId, kAWSProfileAccessKeyId,
                                        secretAccessKey, kAWSProfileSecretAccessKey,
                                        nil];

    NSString *sessionToken = [json objectForKey:kAWSProfileSessionToken];
    if ([sessionToken length]) {
        [credentials setObject:sessionToken forKey:kAWSProfileSessionToken];
    }

    return credentials;
}

+ (NSString *)_awsCLIPath
{
    // Check common locations for the aws CLI
    NSArray *candidates = [NSArray arrayWithObjects:
                           @"/usr/local/bin/aws",
                           @"/opt/homebrew/bin/aws",
                           @"/usr/bin/aws",
                           nil];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in candidates) {
        if ([fm isExecutableFileAtPath:path])
            return path;
    }

    NSLog(@"AWSProfileManager: aws CLI not found in any expected location");
    return nil;
}

@end

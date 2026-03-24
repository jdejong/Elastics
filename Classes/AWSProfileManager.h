//
//  AWSProfileManager.h
//  Elastics
//
//  Resolves AWS credentials from named profiles using the AWS CLI.
//  Supports both static credential profiles and SSO-backed profiles.
//

#import <Foundation/Foundation.h>

extern NSString *const kAWSProfileAccessKeyId;
extern NSString *const kAWSProfileSecretAccessKey;
extern NSString *const kAWSProfileSessionToken;

@interface AWSProfileManager : NSObject

// Resolve credentials for the given AWS profile name.
// Returns a dictionary with kAWSProfileAccessKeyId, kAWSProfileSecretAccessKey,
// and optionally kAWSProfileSessionToken. Returns nil on failure.
+ (NSDictionary *)credentialsForProfile:(NSString *)profileName;

@end

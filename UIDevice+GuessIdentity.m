//
//  guessIdentity.c
//
//  Created by Hwee-Boon Yar on Mar/29/12
//  Modified by Henri Normak on Aug/12/13
//  Copyright (c) 2012 MotionObj. All rights reserved.
//
/*
The MIT License (MIT)

Copyright (c) 2012 Yar Hwee Boon

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/


#import <AddressBook/AddressBook.h>
#import <CommonCrypto/CommonDigest.h>

#import "UIDevice+GuessIdentity.h"

@interface NSString (MD5Hash)
- (NSString *)MD5Hash;
@end

@implementation NSString (MD5Hash)

- (NSString *)MD5Hash {
    //Courtesy http://stackoverflow.com/questions/652300/using-md5-hash-on-a-string-in-cocoa
    const char* cStr = [self UTF8String];
	unsigned char result[16];
	CC_MD5(cStr, strlen(cStr), result);
	return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
			];
}

@end

@implementation UIDevice (GuessIdentity)

- (NSDictionary *)guessedIdentity {
    // Get the name from the device name
    NSString *name = [self.name lowercaseString];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^(.{1,}?)(?:'s)\\s*(?:ipod|iphone|ipad)\\s*(?:mini|touch)?$"
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:NULL];
    
    __block NSString *deviceName = nil;
    [expression enumerateMatchesInString:name options:0 range:NSMakeRange(0, [name length])
                              usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                  if (result) {
                                      if (result.numberOfRanges > 1) {
                                          deviceName = [name substringWithRange:[result rangeAtIndex:1]];
                                          *stop = YES;
                                      }
                                  }
                              }];
    
    if ([deviceName length] == 0)
        return nil;
    
    ABAddressBookRef addressBook = NULL;
    if (ABAddressBookCreateWithOptions != NULL) {
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    } else {
        // Ignore the warning, we only use this call when the new replacement is not available
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        addressBook = ABAddressBookCreate();
#pragma clang diagnostic pop
    }
    
    if (addressBook == NULL)
        return nil;
    
    __block BOOL accessGranted = NO;
    if (ABAddressBookRequestAccessWithCompletion != NULL) { // we're on iOS 6
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else    // We're on iOS 5 or older
        accessGranted = YES;
    
    if (addressBook == NULL || !accessGranted)
        return nil;
    
    NSMutableDictionary* results = [NSMutableDictionary dictionary];
    BOOL matched = NO;
    NSArray *addressBookRecords = (__bridge_transfer NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    for (NSUInteger i = 0; i < [addressBookRecords count]; i++) {
        ABRecordRef person = (__bridge ABRecordRef)(addressBookRecords[i]);
        NSString *firstName = (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
        NSString *lastName = (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
        NSString *fullName = [firstName stringByAppendingFormat:@" %@", lastName];
        
        if ([firstName caseInsensitiveCompare:deviceName] == NSOrderedSame ||
            [lastName caseInsensitiveCompare:deviceName] == NSOrderedSame ||
            [fullName caseInsensitiveCompare:deviceName] == NSOrderedSame) {
            matched = YES;
        }
        
        // If no match, try and match the email or if did match,
        // then populate the email entries
        ABMultiValueRef emailEntries = ABRecordCopyValue(person, kABPersonEmailProperty);
        for (NSUInteger j = 0; j < ABMultiValueGetCount(emailEntries); j++) {
            NSString *email = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(emailEntries, j);
            
            if (!matched) {
                if ([deviceName length] >= 5 && [firstName length] > 0 && [lastName length] > 0 &&
                    [[email lowercaseString] rangeOfString:deviceName].location != NSNotFound) {
                    matched = YES;
                }
            } else {
                NSString *strippedEmail = [[email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
                NSString *avatarURLString = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?d=404", [strippedEmail MD5Hash]];
                NSURL *avatarURL = [NSURL URLWithString:avatarURLString];
                results[GuessIdentityGravatarURLKey] = avatarURL;
                results[GuessIdentityEmailKey] = email;
                break;
            }
        }
        
        CFRelease(emailEntries);
        if (!matched)
            continue;
        
        if (firstName)
            results[GuessIdentityFirstNameKey] = firstName;
        
        if (lastName)
            results[GuessIdentityLastNameKey] = lastName;
        
        if (ABPersonHasImageData(person)) {
            NSData *avatarData = (__bridge_transfer NSData *)ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatOriginalSize);
            if (avatarData) {
                UIImage *image = [UIImage imageWithData:avatarData];
                if (image)
                    results[GuessIdentityAvatarImageKey] = image;
            }
        }
        
        // We matched, so cancel
        break;
    }
    
    CFRelease(addressBook);
    return results;
}

@end

#pragma mark -
#pragma mark Dictionary keys

// NSString values
NSString *const GuessIdentityFirstNameKey = @"GuessIdentityFirstNameKey";
NSString *const GuessIdentityLastNameKey = @"GuessIdentityLastNameKey";
NSString *const GuessIdentityEmailKey = @"GuessIdentityEmailKey";

// An NSURL object or nil if no valid URL could be generated
NSString *const GuessIdentityGravatarURLKey = @"GuessIdentityGravatarURLKey";

// An UIImage avatar for the identity
NSString *const GuessIdentityAvatarImageKey = @"GuessIdentityAvatarImageKey";

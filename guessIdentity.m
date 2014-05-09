//
//  guessIdentity.c
//
//  Created by Hwee-Boon Yar on Mar/29/12.
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
#import <UIKit/UIKit.h>

#import "guessIdentity.h"

//Courtesy http://stackoverflow.com/questions/652300/using-md5-hash-on-a-string-in-cocoa
NSString* md5(NSString* str) {
	const char* cStr = [str UTF8String];
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


//Inspired by http://www.quora.com/Square-company/How-does-Square-know-my-name-in-their-apps-registration-process?srid=TjL
//Returns NSDictionary instance with optional keys except otherwise stated:
//	avatarUrl - pulled from gravatar, returns a HTTP 404 if no avatar (avatarUrl is always present if there's an email address matched
//	avatar - an UIImage*
//	email
//	firstName
//	lastName
NSDictionary* guessIdentity(void) {
	NSString* deviceName = [UIDevice currentDevice].name;

	deviceName = [deviceName lowercaseString];
	for (NSString* s in @[@"'s iphone", @"'s ipad", @"'s ipod touch", @"'s ipod", @"iphone", @"ipad", @"ipod touch", @"ipod"]) {
		deviceName = [deviceName stringByReplacingOccurrencesOfString:s withString:@""];
	}

	if ([deviceName length] <= 3) return nil;

	NSMutableDictionary* results = [NSMutableDictionary dictionary];
	BOOL matched = NO;

	ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, nil);
	NSArray* addressBookEntries = (NSArray*)ABAddressBookCopyArrayOfAllPeople(addressBook);
	for (int i=0; i<[addressBookEntries count]; ++i) {
		ABRecordRef each = addressBookEntries[i];
		NSString* firstName = (NSString*)ABRecordCopyValue(each, kABPersonFirstNameProperty);
		NSString* lastName = (NSString*)ABRecordCopyValue(each, kABPersonLastNameProperty);
		NSString* name = [[NSString stringWithFormat:@"%@ %@", firstName, lastName] lowercaseString];

		if ([[firstName lowercaseString] isEqualToString:deviceName]) {
			matched = YES;
		} else if ([[lastName lowercaseString] isEqualToString:deviceName]) {
			matched = YES;
		} else if ([name isEqualToString:deviceName]) {
			matched = YES;
		}

		ABMultiValueRef emailEntries = ABRecordCopyValue(each, kABPersonEmailProperty);

		for (int i=0; i<ABMultiValueGetCount(emailEntries); ++i) {
			NSString* email = [(NSString*)ABMultiValueCopyValueAtIndex(emailEntries, i) autorelease];

			if (!matched) {
				if ([deviceName length] >= 5 && [firstName length] > 0 && [lastName length] > 0 && [[email lowercaseString] rangeOfString:deviceName].location != NSNotFound) {
					matched = YES;
				}
			}

			if (matched) {
				NSString* avatarUrl = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?d=404", [md5([[email lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) lowercaseString]];
				results[@"avatarUrl"] = avatarUrl;
				results[@"email"] = email;
				break;
			}
		}

		CFRelease(emailEntries);

		if (matched) {
			if ([firstName length] > 0) {
				results[@"firstName"] = firstName;
			}

			if ([lastName length] > 0) {
				results[@"lastName"] = lastName;
			}

			if (ABPersonHasImageData(each)) {
				NSData* avatarData = (NSData*)ABPersonCopyImageDataWithFormat(each, kABPersonImageFormatOriginalSize);
				if (avatarData) {
					results[@"avatar"] = [UIImage imageWithData:avatarData];
					CFRelease(avatarData);
				}
			}
		}

		if (firstName) CFRelease(firstName);
		if (lastName) CFRelease(lastName);

		if (matched) {
			break;
		}
	}

	[addressBookEntries release];
	CFRelease(addressBook);
	return results;
}

//
//  guessIdentity.c
//
//  Created by Hwee-Boon Yar on Mar/29/12.
//
/*
Copyright (c) 2016, Hwee-Boon Yar
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
	for (NSString* s in [NSArray arrayWithObjects:@"'s iphone", @"'s ipad", @"'s ipod touch", @"'s ipod", @"iphone", @"ipad", @"ipod touch", @"ipod", nil]) {
		deviceName = [deviceName stringByReplacingOccurrencesOfString:s withString:@""];
	}

	if ([deviceName length] <= 3) return nil;

	NSMutableDictionary* results = [NSMutableDictionary dictionary];
	BOOL matched = NO;

	ABAddressBookRef addressBook = ABAddressBookCreate();
	NSArray* addressBookEntries = (NSArray*)ABAddressBookCopyArrayOfAllPeople(addressBook);
	for (int i=0; i<[addressBookEntries count]; ++i) {
		ABRecordRef each = [addressBookEntries objectAtIndex:i];
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
				[results setObject:avatarUrl forKey:@"avatarUrl"];
				[results setObject:email forKey:@"email"];
				break;
			}
		}

		CFRelease(emailEntries);

		if (matched) {
			if ([firstName length] > 0) {
				[results setObject:firstName forKey:@"firstName"];
			}

			if ([lastName length] > 0) {
				[results setObject:lastName forKey:@"lastName"];
			}

			if (ABPersonHasImageData(each)) {
				NSData* avatarData = (NSData*)ABPersonCopyImageDataWithFormat(each, kABPersonImageFormatOriginalSize);
				if (avatarData) {
					[results setObject:[UIImage imageWithData:avatarData] forKey:@"avatar"];
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

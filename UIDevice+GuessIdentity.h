//
//  guessIdentity.h
//
//  Created by Hwee-Boon Yar on Mar/29/12.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIDevice (GuessIdentity)

// Returns nil if the user has not permitted the use of the address book
// or if a guess could not be made
// On iOS 6 and above this call blocs when the user permission is asked
- (NSDictionary *)guessedIdentity NS_AVAILABLE_IOS(4_0);

@end

#pragma mark -
#pragma mark Dictionary keys

// NSString values
extern NSString *const GuessIdentityFirstNameKey;
extern NSString *const GuessIdentityLastNameKey;
extern NSString *const GuessIdentityEmailKey;

// An NSURL object or nil if no valid URL could be generated
extern NSString *const GuessIdentityGravatarURLKey;

// An UIImage avatar for the identity
extern NSString *const GuessIdentityAvatarImageKey;

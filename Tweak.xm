#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 793.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_6_1
#define kCFCoreFoundationVersionNumber_iOS_6_1 793.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_7_1
#define kCFCoreFoundationVersionNumber_iOS_7_1 847.26
#endif

@class DOMNode;
@class UIKBTree;

@interface UIKeyboardImpl : UIView
@property(assign, nonatomic) UIResponder<UIKeyInput>* delegate;
-(void)insertText:(id)text;
-(void)deleteBackward;
-(id)textInputTraits;
@end

@interface UIResponder (FullyMaskedPasswords)
@property(assign, nonatomic) NSString* text;
-(void)clearText;
@end

@interface UIFieldEditor : UIScrollView
-(void)_obscureLastCharacter;
@end

@interface UITextField (FullyMaskedPasswords)
-(id)_fieldEditor;
@end

@interface DOMHTMLInputElement
@property int selectionEnd;
@property int selectionStart;
@property int maxLength;
@end

@interface UIKBTree
-(void)setOverrideDisplayString:(NSString*)string;
-(int)interactionType;
@end

@interface WKWebView
-(void)evaluateJavaScript:(id)script completionHandler:(id)handler;
@end

static bool inTouch = NO;
static bool hideKeys = NO;
static NSMutableArray* overridden;

void obscureLastCharacter(id field) {
	@try {
		if (field == nil) {
			return;
		}

		UITextInputTraits* traits = [field textInputTraits];
		if (traits == nil || ![traits isSecureTextEntry]) {
			return;
		}

		if ([field isKindOfClass:[%c(UIThreadSafeNode) class]]) {

			DOMNode* node = MSHookIvar<DOMNode*>(field, "_node");
			if ([node isKindOfClass:[%c(DOMHTMLInputElement) class]]) {
				DOMHTMLInputElement* element = (DOMHTMLInputElement*)node;

				int selectionStart = element.selectionStart;
				int maxLength = element.maxLength;
				if (element.selectionStart == element.selectionEnd) {
					if (maxLength == selectionStart) {
						element.maxLength = maxLength + 1;
					}
					[field insertText:@"."];
					[field deleteBackward];
					if (maxLength == selectionStart) {
						element.maxLength = maxLength;
					}
				}
			}

		} else if ([field isKindOfClass:[%c(WKContentView) class]]) {

			NSString* incrementJs = @"for(var z=document.getElementsByTagName(\"input\"),x=z.length;x--;){if(z[x].type===\"password\"&&z[x].maxLength)z[x].maxLength++;} ";
			NSString* decrementJs = @"for(var z=document.getElementsByTagName(\"input\"),x=z.length;x--;){if(z[x].type===\"password\"&&z[x].maxLength)z[x].maxLength--;} ";

			WKWebView* webView = MSHookIvar<WKWebView*>(field, "_webView");

			[webView evaluateJavaScript:incrementJs completionHandler:^(NSString* result, NSError* error) {
				[field insertText:@"."];
				[field deleteBackward];
				[webView evaluateJavaScript:decrementJs completionHandler:nil];
			}];

		} else if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {

			if ([field respondsToSelector:@selector(_fieldEditor)]) {
				UIFieldEditor* fieldEditor = [field performSelector:@selector(_fieldEditor)];
				[fieldEditor _obscureLastCharacter];
			}

		} else if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_6_0) {

			// Required because deleteBackward doesn't work.
			if ([field isKindOfClass:[%c(DevicePINPane) class]]) {
				return;
			}

			NSString* text = [field text];
			[field insertText:@"."];
			if (![[field text] isEqualToString:text]) {
				[field deleteBackward];
			}
			if (![[field text] isEqualToString:text]) {
				[field clearText];
				[field insertText:text];
			}
		}

	} @catch (NSException* exception) {
		NSLog(@"%@", exception.reason);
	}

}

%hook UIKeyboardLayoutStar
-(void)showKeyboardWithInputTraits:(UITextInputTraits*)inputTraits screenTraits:(id)screenTraits splitTraits:(id)splitTraits {
	@try {
		hideKeys = [inputTraits isSecureTextEntry];
	} @catch (NSException* exception) {
		NSLog(@"%@", exception.reason);
		hideKeys = NO;
	}

	%orig;
}

-(void)touchDown:(id)touch executionContext:(id)context {
	inTouch = YES;
	%orig;
}

-(void)touchUp:(id)touch executionContext:(id)context {
	%orig;

	inTouch = NO;

	@try {
		UIKBTree* key = [overridden firstObject];
		while (key != nil) {
			[key setOverrideDisplayString:nil];
			[overridden removeObject:key];
			key = [overridden firstObject];
		}
	} @catch (NSException* exception) {
		NSLog(@"%@", exception.reason);
	}
}

-(id)keyHitTest:(struct CGPoint)point {
	id r = %orig;

	@try {
		if (inTouch && hideKeys && [r interactionType] == 2) {
			if (![overridden containsObject:r]) {
				[(UIKBTree*)r setOverrideDisplayString:@"\u2022"];
				[overridden addObject:r];
			}
		}
	} @catch (NSException* exception) {
		NSLog(@"%@", exception.reason);
	}

	return r;
}

-(void)deactivateActiveKeys {
	%orig;

	inTouch = NO;

	@try {
		UIKBTree* key = [overridden firstObject];
		while (key != nil) {
			[key setOverrideDisplayString:nil];
			[overridden removeObject:key];
			key = [overridden firstObject];
		}
	} @catch (NSException* exception) {
		NSLog(@"%@", exception.reason);
	}
}
%end

%hook UIKeyboardImpl
-(void)callChanged {
	%orig;

	obscureLastCharacter(self.delegate);
}
%end

%hook UITextField
-(void)insertText:(NSString*)text {
	%orig;

	obscureLastCharacter(self);
}
%end

%group Hook_iOS7_SpringBoard
%hook SBUIAlphanumericPasscodeEntryField
- (void)notePasscodeFieldTextDidChange {
	%orig;

	@try {
		UITextField* textField = MSHookIvar<UITextField*>(self, "_textField");
		UIFieldEditor* fieldEditor = [textField _fieldEditor];
		[fieldEditor _obscureLastCharacter];
	} @catch (NSException* exception) {
		NSLog(@"%@", exception.reason);
	}
}
%end
%end

%ctor {
	if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
			%init(Hook_iOS7_SpringBoard);
		}
	}
	%init;

	overridden = [NSMutableArray arrayWithCapacity:20];
}


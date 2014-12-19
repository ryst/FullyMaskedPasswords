#define incrementJs @"for(var z=document.getElementsByTagName(\"input\"),x=z.length;x--;){if(z[x].type===\"password\"&&z[x].maxLength&&!z[x].maxLengthFMP){z[x].maxLengthFMP=z[x].maxLength++;}} "
#define decrementJs @"for(var z=document.getElementsByTagName(\"input\"),x=z.length;x--;){if(z[x].type===\"password\"&&z[x].maxLengthFMP)z[x].maxLength=z[x].maxLengthFMP;z[x].maxLengthFMP=null;} "

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
-(id)textInputTraits;
@end

@interface UIFieldEditor : UIScrollView
-(void)_obscureLastCharacter;
@end

@interface UITextField (FullyMaskedPasswords)
-(id)_fieldEditor;
@end

@interface UIWebDocumentView
-(id)formElement;
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

@interface WKContentView
-(id)textInputTraits;
-(void)insertText:(id)text;
-(void)deleteBackward;
@end

static bool inTouch = NO;
static bool hideKeys = NO;
static NSMutableArray* overridden;
static WKContentView* currentWKContentView;

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

		} else if (![field isKindOfClass:[%c(WKContentView) class]]) {

			if ([field respondsToSelector:@selector(_fieldEditor)]) {
				UIFieldEditor* fieldEditor = [field performSelector:@selector(_fieldEditor)];
				[fieldEditor _obscureLastCharacter];
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
	if (currentWKContentView) {
		WKWebView* webView = MSHookIvar<WKWebView*>(currentWKContentView, "_webView");
		[webView evaluateJavaScript:decrementJs completionHandler:nil];
		currentWKContentView = nil;
	}

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

%hook UIWebDocumentView
-(void)paste:(id)menu {
	%orig;
	obscureLastCharacter(self.formElement);
}
%end

%hook WKContentView
-(void)paste:(id)menu {
	UITextInputTraits* traits = [self textInputTraits];
	if (traits == nil || ![traits isSecureTextEntry])
		return %orig;

	if (currentWKContentView && currentWKContentView == self) {
		%orig;
		[currentWKContentView insertText:@"."];
		[currentWKContentView deleteBackward];
	} else {
		currentWKContentView = self;
		WKWebView* webView = MSHookIvar<WKWebView*>(currentWKContentView, "_webView");
		[webView evaluateJavaScript:incrementJs completionHandler:^(NSString* result, NSError* error) {
			%orig;
			[currentWKContentView insertText:@"."];
			[currentWKContentView deleteBackward];
		}];
	}
}
%end

%hook UIKeyboardImpl
-(void)insertText:(NSString*)text {
	if (!self.delegate || ![self.delegate respondsToSelector:@selector(textInputTraits)])
		return %orig;

	UITextInputTraits* traits = [self.delegate textInputTraits];
	if (traits == nil || ![traits isSecureTextEntry])
		return %orig;

	if ([self.delegate isKindOfClass:[%c(WKContentView) class]]) {
		WKContentView* delegate = (WKContentView*)self.delegate;
		if (currentWKContentView && currentWKContentView == delegate) {
			%orig;
			[currentWKContentView insertText:@"."];
			[currentWKContentView deleteBackward];
		} else {
			currentWKContentView = delegate;
			WKWebView* webView = MSHookIvar<WKWebView*>(currentWKContentView, "_webView");
			[webView evaluateJavaScript:incrementJs completionHandler:^(NSString* result, NSError* error) {
				%orig;
				[currentWKContentView insertText:@"."];
				[currentWKContentView deleteBackward];
			}];
		}
	} else {
		%orig;
		obscureLastCharacter(self.delegate);
	}
}
%end

%group Hook_SpringBoard
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
	if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
		%init(Hook_SpringBoard);
	}
	%init;

	overridden = [NSMutableArray arrayWithCapacity:20];
}


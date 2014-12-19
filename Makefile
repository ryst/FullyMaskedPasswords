ARCHS := armv7 arm64
TARGET := iphone:clang::7.0

include theos/makefiles/common.mk

TWEAK_NAME = FullyMaskedPasswords
FullyMaskedPasswords_FILES = Tweak.xm
FullyMaskedPasswords_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

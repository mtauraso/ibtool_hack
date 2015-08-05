# Xcode 6.1.1 bug workaround

ibtool had a bug in Xcode 6.1.1 where multiple instances of it race to create the localized strings dirs in the built product directory
Two instances of ibtoold (a launchd daemon started by ibtool) both see that the directory doesn't exist. Both call mkdir
mkdir fails for one and fails the build.

http://www.openradar.me/radar?id=6107934530469888

This will patch Xcode so as to workaround this particular issue.


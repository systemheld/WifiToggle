# WifiToggle

this is a small daemon to disable Wifi network if a ethernet connection is plugged in and re-enables it when ethernet is pulled. You may run this as a unpriviled user or as root.

## Todo
[] add a Menu Bar Icon
[] add to LoginItems instead of running as launchd job

## Example launchd plist

```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.sample.WifiToggle</string>
	<key>Program</key>
	<string>/usr/local/bin/WifiToggle</string>
	<key>ProgramArguments</key>
	<array>
		<string>--start</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
```

## 3rd-Party Components

AppIcon is composed out of the [rrze-icon-set](https://github.com/RRZE-PP/rrze-icon-set).
# borg-wrapper

## Borg Wrapper is a lightweight wrapper used the run (or schedule) Borg backups securely on macOS.

**Why Borg Wrapper?** Because a native app is required to run (or schedule) Borg backups securely on macOS.

Without a native app, one has to allow `zsh` access to restricted paths such as `~/Documents` which can lead to security vulnerabilities.

All credits go to the amazing [people](https://github.com/borgbackup/borg/graphs/contributors) who develop Borg. Thanks guys. 🙌

## Dependencies

- [Borg](https://www.borgbackup.org/)

## Installation

> Heads-up: [Homebrew](https://brew.sh/) users can skip steps 1 and 2 by running `brew install --cask sunknudsen/tap/borg-wrapper`.

### Step 1: go to [https://github.com/sunknudsen/borg-wrapper/releases/latest](https://github.com/sunknudsen/borg-wrapper/releases/latest) and download latest `.dmg` release

### Step 2: double-click `.dmg` release and drag and drop Borg Wrapper to the “Applications” folder

### Step 3: create `/usr/local/bin/borg-backup.sh` backup script

### Step 4: create `/usr/local/var/log` folder

```
mkdir -p /usr/local/var/log
```

## Usage

By default, Borg Wrapper runs `/usr/local/bin/borg-backup.sh` and logs `stdout` and `stderr` to `/usr/local/var/log/borg-backup.log`.

These defaults can be overridden using a JSON config file that has the following properties.

```console
$ cat /Users/sunknudsen/Desktop/borg-wrapper/config.json
{
  "script": "/Users/sunknudsen/Desktop/borg-wrapper/borg-backup.sh",
  "logFile": "/Users/sunknudsen/Desktop/borg-wrapper/borg-backup.log",
  "initiatedNotifications": true,
  "completedNotifications": true,
  "failedNotifications": true
}
```

```console
$ cat /Users/sunknudsen/Desktop/borg-wrapper/borg-backup.sh
#! /bin/sh

set -e

repo="user@host:backup"
prefix="{user}-macbook-pro-"

export BORG_PASSCOMMAND="security find-generic-password -a $USER -s borg-passphrase -w"
export BORG_RSH="ssh -i ~/.ssh/borg-append-only"

borg create \
  --filter "AME" \
  --list \
  --stats \
  --verbose \
  "$repo::$prefix{now:%F-%H%M%S}" \
  "/Users/sunknudsen/Desktop/privacy-guides"
```

```shell
open /Applications/Borg\ Wrapper.app --args /Users/sunknudsen/Desktop/borg-wrapper/config.json
```

## Scheduling backups

The following runs Borg Wrapper once an hour or when computer wakes from sleep (if scheduled task was omitted).

```shell
mkdir -p ~/Library/LaunchAgents
cat << EOF > ~/Library/LaunchAgents/local.borg-wrapper.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>Borg Wrapper.app</string>

    <key>ProgramArguments</key>
    <array>
      <string>open</string>
      <string>/Applications/Borg Wrapper.app</string>
    </array>

    <key>RunAtLoad</key>
    <false/>

    <key>StartCalendarInterval</key>
    <dict>
      <key>Minute</key>
      <integer>0</integer>
    </dict>
  </dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/local.borg-wrapper.plist
```
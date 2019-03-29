# TeslaCam Merging Scripts

This script is currently designed to probe the `SavedClips` folder of a
flash drive used with Tesla's Sentry Mode, merge the three camera feeds
into one video file, add a timestamp, and then concatenate the one minute
clips into a full-lenth ten minute clip for easier browsing.
Running `teslacam_merge.sh` will search the mounted USB drives for the
`TeslaCam/SavedClips` folder, and parse any folders of video files found
there. If it detects that it has already processed the folder (because
the output already exists), it will skip that folder.

## System support

I use Linux at home and work, so the script was first developed with a Linux
system in mind, with `ffmpeg` already installed. It will detect the USB
drive by probing `/dev/disk/by-id/*` for USB drives. Currently the script
assumes that only the TeslaCam USB is plugged in.

It also will run on Windows, provided that the
[Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10) is
installed, and `ffmpeg` is installed into the subsystem.
In this case, the connected USB drives will be probed with the `WMIC.exe`
Windows tool, and any drive containing "`Tesla`" in the volume name will
be mounted into the WSL system and processed as desribed above.
If all the files in this repo are copied into the root of the TeslaCam drive,
the script can be run easily by double-clicking on `teslacam_merge.bat`. This
step is necessary because AutoRun is disabled on USB drives in modern versions
of Windows due to security concerns.

## Other options

After working on this, I found a
[more advanced project](https://github.com/ehendrix23/tesla_dashcam) written
in Python that will do a lot of the same things (and more), but requires a Python
installation, obviously. Give both a shot!

# snaprestore

> snaprestore [volume] [snapshot]

Easily restore rootfs from the command line.

## Features

* Fair amount of testing
* Cleans up `/var`
* Renames snapshot to original name
* Removes jailbreak apps from icon cache
* Works on any jailbreak *(hopefully)*

## Installation

A build of `snaprestore` is available on [Procursus](https://github.com/ProcursusTeam/Procursus), which you can install if your device is already setup with an instance of the build system.

Alternatively, you can compile `snaprestore` on your device using Make.

    make install

If you need a Debian package for later use, use the following command

    make package

Check out the [Makefile](Makefile) to see what options you might need to setup for `snaprestore` to build properly.

## License

`snaprestore` has been licensed under the [BSD-2 Clause License](LICENCE).

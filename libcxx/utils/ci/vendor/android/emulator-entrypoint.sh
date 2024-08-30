#!/usr/bin/env bash
#===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===----------------------------------------------------------------------===##

# This script is the entrypoint of an Android Emulator Docker container.

set -e

if [ -z "${ADBKEY_PUB}" ]; then
    # TODO: Upgrade to a fatal error when/if port 5037 is no longer exposed.
    echo "An ADB public key should be provided to allow connections to the emulator"
else
    # TODO: What are the implications of providing only the public key? Presumably
    # this means that "adb" inside the container can't connect to the emulator?
    mkdir -p ~/.android
    rm -f ~/.android/adbkey ~/.android/adbkey.pub
    echo "${ADBKEY_PUB}" > ~/.android/adbkey.pub
fi

# The container's /dev/kvm has the same UID+GID as the host device. Changing the
# ownership inside the container doesn't affect the UID+GID on the host.
sudo chown emulator:emulator /dev/kvm

# Start an adb host server. `adb start-server` blocks until the port is ready.
# Use ADB_REJECT_KILL_SERVER=1 to ensure that an adb protocol version mismatch
# doesn't kill the adb server.
ADB_REJECT_KILL_SERVER=1 adb -a start-server

# TODO: Maybe commenting this out will enable adb key checking?
# # This syntax (using an IP address of 127.0.0.1 rather than localhost) seems to
# # prevent the adb client from ever spawning an adb host server.
# export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037

# The AVD could already exist if the Docker container were stopped and then
# restarted.
if [ ! -d ~/.android/avd/emulator.avd ]; then
    # N.B. AVD creation takes a few seconds and creates a mostly-empty
    # multi-gigabyte userdata disk image. (It's not useful to create the AVDs in
    # advance.)
    avdmanager --verbose create avd --name emulator \
        --package "${EMU_PACKAGE_NAME}" --device pixel_5
fi

# The emulator ports are localhost-only, so forward connections from outside the
# container.
socat -d tcp-listen:5555,reuseaddr,fork tcp:127.0.0.1:5557 &

# TODO: How do we know that socat is actually ready to forward connections? What if
# it forwards a connection before the emulator is ready?

# Use exec so that the emulator is PID 1, so that `docker stop` kills the
# emulator.
exec emulator @emulator -no-audio -no-window -no-metrics \
    -partition-size "${EMU_PARTITION_SIZE}" \
    -ports 5556,5557

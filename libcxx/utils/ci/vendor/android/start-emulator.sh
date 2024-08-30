#!/usr/bin/env bash
#===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===----------------------------------------------------------------------===##

# Starts a new Docker container using a Docker image containing the Android
# Emulator and an OS image. Stops and removes the old container if it exists
# already.

set -e

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${THIS_DIR}/emulator-functions.sh"

EMU_IMG="${1}"
if ! validate_emu_img "${EMU_IMG}"; then
    echo "error: The first argument must be a valid emulator image." >&2
    exit 1
fi

# TODO: Somehow if the emulator is already running, that's probably OK? (But make sure we delete "enough" stuff and overwrite libc++_shared.so)
#"${THIS_DIR}/stop-emulator.sh"
if ! docker container inspect libcxx-ci-android-emulator &>/dev/null; then

    # TODO: Make sure ~/.android/adbkey.pub exists first! (nope -- see below)

    # Start the container.
    docker run --name libcxx-ci-android-emulator --detach --device /dev/kvm \
        -eEMU_PARTITION_SIZE=8192 \
        $(docker_image_of_emu_img ${EMU_IMG})

    # TODO: When I write ~/.android/adbkey.pub inside the emulator container, I
    # don't write ~/.android/adbkey. I don't know how that would work, but also it
    # doesn't work -- the container (emulator and/or adb server) creates a new
    # adbkey *and* adbkey.pub. So instead, I just don't propagate adbkey, and yet
    # the outer adb client/server are still able to connect to the emulator.
    #
    # Does the emulator just not care about checking the adbkey?
    #
    # See https://github.com/google/android-emulator-container-scripts/blob/master/emu/templates/launch-emulator.sh, install_adb_keys()
    #    -eADBKEY_PUB="$(cat ~/.android/adbkey.pub)"
    #
    # See adb, where load_userkey calls generate_key. It doesn't seem to care if only ~/.android/adbkey.pub exists.
    # See adb's use of "ro.adb.secure". It defaults to not-secure, and the two emulator containers I have don't set the property,
    # so no auth is required.
    #

    # TODO: Are there Android emulator images that *do* set ro.adb.secure?
    # TODO: Also, what about Cuttlefish?
fi

ERR=0
docker exec libcxx-ci-android-emulator emulator-wait-for-ready.sh || ERR=${?}
echo "Emulator container initial logs:"
docker logs libcxx-ci-android-emulator
if [ ${ERR} != 0 ]; then
    exit ${ERR}
fi

# Make sure the device is accessible from outside the emulator container and
# advertise to the user that this script exists.
. "${THIS_DIR}/setup-env-for-emulator.sh"
adb connect "${ANDROID_SERIAL}"
adb wait-for-device

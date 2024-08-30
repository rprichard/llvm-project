#===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===----------------------------------------------------------------------===##

export ANDROID_SERIAL="$(docker inspect \
    -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    libcxx-ci-android-emulator):5555"

echo "setup-env-for-emulator.sh: setting ANDROID_SERIAL to ${ANDROID_SERIAL}"

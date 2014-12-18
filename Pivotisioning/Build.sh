#!/bin/sh

#  Build.sh
#  Pivotisioning
#
#  Created by Ivan Rodriguez on 2014-12-17.
#  Copyright (c) 2014 Pivotal Labs. All rights reserved.

xcodebuild -exportArchive -exportFormat ipa -archivePath "${1}" -exportPath "${2}" -exportProvisioningProfile "${3}"
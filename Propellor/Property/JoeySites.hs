-- | Specific configuation for Joey Hess's sites. Probably not useful to
-- others except as an example.

module Propellor.Property.JoeySites where

import Propellor
import qualified Propellor.Property.Apt as Apt

oldUseNetshellBox :: Property
oldUseNetshellBox = check (not <$> Apt.isInstalled "oldusenet") $
	propertyList ("olduse.net shellbox")
		[ Apt.installed (words "build-essential devscripts debhelper git libncursesw5-dev libpcre3-dev pkg-config bison libicu-dev libidn11-dev libcanlock2-dev libuu-dev ghc libghc-strptime-dev libghc-hamlet-dev libghc-ifelse-dev libghc-hxt-dev libghc-utf8-string-dev libghc-missingh-dev libghc-sha-dev")
			`describe` "olduse.net build deps"
		, scriptProperty
			[ "rm -rf /root/tmp/oldusenet" -- idenpotency
			, "git clone git://olduse.net/ /root/tmp/oldusenet/source"
			, "cd /root/tmp/oldusenet/source/"
			, "dpkg-buildpackage -us -uc"
			, "dpkg -i ../oldusenet*.deb || true"
			, "apt-get -fy install" -- dependencies
			, "rm -rf /root/tmp/oldusenet"
			] `describe` "olduse.net built"
		]
{-# LANGUAGE PackageImports #-}

module Propellor.Attr where

import Propellor.Types
import Propellor.Types.Attr

import "mtl" Control.Monad.Reader
import qualified Data.Set as S
import qualified Data.Map as M
import Data.Maybe
import Data.Monoid
import Control.Applicative

pureAttrProperty :: Desc -> Attr -> Property 
pureAttrProperty desc = Property ("has " ++ desc) (return NoChange)

os :: System -> Property
os system = pureAttrProperty ("Operating " ++ show system) $
	mempty { _os = Just system }

getOS :: Propellor (Maybe System)
getOS = asks (_os . hostAttr)

-- | Indidate that a host has an A record in the DNS.
--
-- TODO check at run time if the host really has this address.
-- (Can't change the host's address, but as a sanity check.)
ipv4 :: String -> Property
ipv4 = addDNS . Address . IPv4

-- | Indidate that a host has an AAAA record in the DNS.
ipv6 :: String -> Property
ipv6 = addDNS . Address . IPv6

-- | Indicates another name for the host in the DNS.
alias :: Domain -> Property
alias = addDNS . CNAME . AbsDomain

addDNS :: Record -> Property
addDNS r = pureAttrProperty (rdesc r) $
	mempty { _dns = S.singleton r }
  where
	rdesc (CNAME d) = unwords ["alias", ddesc d]
	rdesc (Address (IPv4 addr)) = unwords ["ipv4", addr]
	rdesc (Address (IPv6 addr)) = unwords ["ipv6", addr]
	rdesc (MX n d) = unwords ["MX", show n, ddesc d]
	rdesc (NS d) = unwords ["NS", ddesc d]
	rdesc (TXT s) = unwords ["TXT", s]
	rdesc (SRV x y z d) = unwords ["SRV", show x, show y, show z, ddesc d]

	ddesc (AbsDomain domain) = domain
	ddesc (RelDomain domain) = domain
	ddesc RootDomain = "@"

sshPubKey :: String -> Property
sshPubKey k = pureAttrProperty ("ssh pubkey known") $
	mempty { _sshPubKey = Just k }

getSshPubKey :: Propellor (Maybe String)
getSshPubKey = asks (_sshPubKey . hostAttr)

hostMap :: [Host] -> M.Map HostName Host
hostMap l = M.fromList $ zip (map hostName l) l 

findHost :: [Host] -> HostName -> Maybe Host
findHost l hn = M.lookup hn (hostMap l)

getAddresses :: Attr -> [IPAddr]
getAddresses = mapMaybe getIPAddr . S.toList . _dns

hostAddresses :: HostName -> [Host] -> [IPAddr]
hostAddresses hn hosts = case hostAttr <$> findHost hosts hn of
	Nothing -> []
	Just attr -> mapMaybe getIPAddr $ S.toList $ _dns attr

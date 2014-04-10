{-# LANGUAGE PackageImports #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Propellor.Types where

import Data.Monoid
import Control.Applicative
import System.Console.ANSI
import "mtl" Control.Monad.Reader
import "MonadCatchIO-transformers" Control.Monad.CatchIO

type HostName = String
type GroupName = String
type UserName = String

-- | The core data type of Propellor, this reprecents a property
-- that the system should have, and an action to ensure it has the
-- property.
data Property = Property
	{ propertyDesc :: Desc
	-- | must be idempotent; may run repeatedly
	, propertySatisfy :: Propellor Result
	}

-- | A property that can be reverted.
data RevertableProperty = RevertableProperty Property Property

-- | Propellor's monad provides read-only access to attributes of the
-- system.
newtype Propellor a = Propellor { runWithHostAttr :: ReaderT HostAttr IO a }
	deriving
		( Monad
		, Functor
		, Applicative
		, MonadReader HostAttr 
		, MonadIO
		, MonadCatchIO
		)

-- | The attributes of a system. For example, its hostname.
newtype HostAttr = HostAttr
	{ _hostname :: HostName
	}

mkHostAttr :: HostName -> HostAttr
mkHostAttr = HostAttr 

getHostName :: Propellor HostName
getHostName = asks _hostname

class IsProp p where
	-- | Sets description.
	describe :: p -> Desc -> p
	toProp :: p -> Property
	-- | Indicates that the first property can only be satisfied
	-- once the second one is.
	requires :: p -> Property -> p

instance IsProp Property where
	describe p d = p { propertyDesc = d }
	toProp p = p
	x `requires` y = Property (propertyDesc x) $ do
		r <- propertySatisfy y
		case r of
			FailedChange -> return FailedChange
			_ -> propertySatisfy x

instance IsProp RevertableProperty where
	-- | Sets the description of both sides.
	describe (RevertableProperty p1 p2) d = 
		RevertableProperty (describe p1 d) (describe p2 ("not " ++ d))
	toProp (RevertableProperty p1 _) = p1
	(RevertableProperty p1 p2) `requires` y =
		RevertableProperty (p1 `requires` y) p2

type Desc = String

data Result = NoChange | MadeChange | FailedChange
	deriving (Read, Show, Eq)

instance Monoid Result where
	mempty = NoChange

	mappend FailedChange _ = FailedChange
	mappend _ FailedChange = FailedChange
	mappend MadeChange _ = MadeChange
	mappend _ MadeChange = MadeChange
	mappend NoChange NoChange = NoChange

-- | High level descritption of a operating system.
data System = System Distribution Architecture
	deriving (Show)

data Distribution
	= Debian DebianSuite
	| Ubuntu Release
	deriving (Show)

data DebianSuite = Experimental | Unstable | Testing | Stable | DebianRelease Release
	deriving (Show, Eq)

type Release = String

type Architecture = String

-- | Results of actions, with color.
class ActionResult a where
	getActionResult :: a -> (String, ColorIntensity, Color)

instance ActionResult Bool where
	getActionResult False = ("failed", Vivid, Red)
	getActionResult True = ("done", Dull, Green)

instance ActionResult Result where
	getActionResult NoChange = ("ok", Dull, Green)
	getActionResult MadeChange = ("done", Vivid, Green)
	getActionResult FailedChange = ("failed", Vivid, Red)

data CmdLine
	= Run HostName
	| Spin HostName
	| Boot HostName
	| Set HostName PrivDataField
	| AddKey String
	| Continue CmdLine
	| Chain HostName
	| Docker HostName
  deriving (Read, Show, Eq)

-- | Note that removing or changing field names will break the
-- serialized privdata files, so don't do that!
-- It's fine to add new fields.
data PrivDataField
	= DockerAuthentication
	| SshPrivKey UserName
	| Password UserName
	| PrivFile FilePath
	deriving (Read, Show, Ord, Eq)



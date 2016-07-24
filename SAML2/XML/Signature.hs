{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
-- |
-- XML Signature Syntax and Processing
--
-- <http://www.w3.org/TR/2008/REC-xmldsig-core-20080610/> (selected portions)
module SAML2.XML.Signature where

import Control.Applicative ((<|>))
import Crypto.Number.Serialize (i2osp, i2ospOf_, os2ip)
import Crypto.Hash.Algorithms (SHA1(SHA1))
import qualified Crypto.PubKey.DSA as DSA
import qualified Crypto.PubKey.RSA.Types as RSA
import qualified Crypto.PubKey.RSA.PKCS15 as RSA
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as Base64
import Data.Monoid ((<>))

import SAML2.XML
import qualified SAML2.XML.Schema as XS
import qualified SAML2.XML.Pickle as XP
import qualified SAML2.XML.Canonical as C14N

nsFrag :: String -> URI
nsFrag = httpURI "www.w3.org" "/2000/09/xmldsig" "" . ('#':)

ns :: Namespace 
ns = mkNamespace "ds" $ nsFrag ""

xpElem :: String -> XP.PU a -> XP.PU a
xpElem = xpTrimElemNS ns

-- |§4.0.1
type CryptoBinary = Integer -- as Base64Binary

xpCryptoBinary :: XP.PU CryptoBinary
xpCryptoBinary = XP.xpWrap (os2ip, i2osp) XS.xpBase64Binary

-- |§4.1
data Signature = Signature
  { signatureId :: Maybe ID
  , signatureSignedInfo :: SignedInfo
  , signatureSignatureValue :: SignatureValue
  , signatureKeyInfo :: Maybe KeyInfo
  , signatureObject :: [Object]
  } deriving (Eq, Show)

instance XP.XmlPickler Signature where
  xpickle = xpElem "Signature" $
    [XP.biCase|((((i, s), v), k), o) <-> Signature i s v k o|] 
    XP.>$<  (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< XP.xpickle
      XP.>*< XP.xpickle
      XP.>*< XP.xpOption XP.xpickle
      XP.>*< XP.xpList XP.xpickle)

-- |§4.2
data SignatureValue = SignatureValue
  { signatureValueId :: Maybe ID
  , signatureValue :: XS.Base64Binary
  } deriving (Eq, Show)

instance XP.XmlPickler SignatureValue where
  xpickle = xpElem "SignatureValue" $
    [XP.biCase|(i, v) <-> SignatureValue i v|] 
    XP.>$< (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< XS.xpBase64Binary)

-- |§4.3
data SignedInfo = SignedInfo
  { signedInfoId :: Maybe ID
  , signedInfoCanonicalizationMethod :: CanonicalizationMethod
  , signedInfoSignatureMethod :: SignatureMethod
  , signedInfoReference :: List1 Reference
  } deriving (Eq, Show)

instance XP.XmlPickler SignedInfo where
  xpickle = xpElem "SignedInfo" $
    [XP.biCase|(((i, c), s), r) <-> SignedInfo i c s r|] 
    XP.>$< (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< XP.xpickle
      XP.>*< XP.xpickle
      XP.>*< xpList1 XP.xpickle)

-- |§4.3.1
data CanonicalizationMethod = CanonicalizationMethod 
  { canonicalizationMethodAlgorithm :: IdentifiedURI C14N.CanonicalizationAlgorithm
  , canonicalizationMethod :: Nodes
  } deriving (Eq, Show)

instance XP.XmlPickler CanonicalizationMethod where
  xpickle = xpElem "CanonicalizationMethod" $
    [XP.biCase|(a, x) <-> CanonicalizationMethod a x|] 
    XP.>$< (XP.xpAttr "Algorithm" XP.xpickle
      XP.>*< xpAnyCont)

-- |§4.3.2
data SignatureMethod = SignatureMethod
  { signatureMethodAlgorithm :: IdentifiedURI SignatureAlgorithm
  , signatureMethodHMACOutputLength :: Maybe Int
  , signatureMethod :: Nodes
  } deriving (Eq, Show)

instance XP.XmlPickler SignatureMethod where
  xpickle = xpElem "SignatureMethod" $
    [XP.biCase|((a, l), x) <-> SignatureMethod a l x|] 
    XP.>$< (XP.xpAttr "Algorithm" XP.xpickle
      XP.>*< XP.xpOption (xpElem "HMACOutputLength" XP.xpickle)
      XP.>*< xpAnyCont)

-- |§4.3.3
data Reference = Reference
  { referenceId :: Maybe ID
  , referenceURI :: Maybe AnyURI
  , referenceType :: Maybe AnyURI -- xml object type
  , referenceTransforms :: Maybe Transforms
  , referenceDigestMethod :: DigestMethod
  , referenceDigestValue :: XS.Base64Binary -- ^§4.3.3.6
  } deriving (Eq, Show)

instance XP.XmlPickler Reference where
  xpickle = xpElem "Reference" $
    [XP.biCase|(((((i, u), t), f), m), v) <-> Reference i u t f m v|] 
    XP.>$<  (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< XP.xpAttrImplied "URI" XS.xpAnyURI
      XP.>*< XP.xpAttrImplied "Type" XS.xpAnyURI
      XP.>*< XP.xpOption XP.xpickle
      XP.>*< XP.xpickle
      XP.>*< xpElem "DigestValue" XS.xpBase64Binary)

-- |§4.3.3.4
newtype Transforms = Transforms{ transforms :: List1 Transform }
  deriving (Eq, Show)

instance XP.XmlPickler Transforms where
  xpickle = xpElem "Transforms" $
    [XP.biCase|l <-> Transforms l|]
    XP.>$< xpList1 XP.xpickle

data Transform = Transform
  { transformAlgorithm :: IdentifiedURI TransformAlgorithm
  , transform :: [TransformElement]
  } deriving (Eq, Show)

instance XP.XmlPickler Transform where
  xpickle = xpElem "Transform" $
    [XP.biCase|(a, l) <-> Transform a l|]
    XP.>$< (XP.xpAttr "Algorithm" XP.xpickle
      XP.>*< XP.xpList XP.xpickle)

data TransformElement
  = TransformElementXPath XString
  | TransformElement Node 
  deriving (Eq, Show)

instance XP.XmlPickler TransformElement where
  xpickle = [XP.biCase|
      Left s  <-> TransformElementXPath s
      Right x <-> TransformElement x |]
    XP.>$< (xpElem "XPath" XS.xpString
      XP.>|< xpTrimAnyElem)

-- |§4.3.3.5
data DigestMethod = DigestMethod
  { digestAlgorithm :: IdentifiedURI DigestAlgorithm
  , digest :: [Node]
  } deriving (Eq, Show)

instance XP.XmlPickler DigestMethod where
  xpickle = xpElem "DigestMethod" $
    [XP.biCase|(a, d) <-> DigestMethod a d|]
    XP.>$< (XP.xpAttr "Algorithm" XP.xpickle
      XP.>*< xpAnyCont)

-- |§4.4
data KeyInfo = KeyInfo
  { keyInfoId :: Maybe ID
  , keyInfoElements :: List1 KeyInfoElement
  } deriving (Eq, Show)

xpKeyInfoType :: XP.PU KeyInfo
xpKeyInfoType = [XP.biCase|(i, l) <-> KeyInfo i l|] 
  XP.>$< (XP.xpAttrImplied "Id" XS.xpID
    XP.>*< xpList1 XP.xpickle)

instance XP.XmlPickler KeyInfo where
  xpickle = xpElem "KeyInfo" xpKeyInfoType

data KeyInfoElement
  = KeyName XString -- ^§4.4.1
  | KeyInfoKeyValue KeyValue
  | RetrievalMethod
    { retrievalMethodURI :: URI
    , retrievalMethodType :: Maybe URI
    , retrievalMethodTransforms :: Maybe Transforms
    } -- ^§4.4.3
  | X509Data
    { x509Data :: List1 X509Element
    } -- ^§4.4.4
  | PGPData
    { pgpKeyID :: Maybe XS.Base64Binary
    , pgpKeyPacket :: Maybe XS.Base64Binary
    , pgpData :: Nodes
    } -- ^§4.4.5
  | SPKIData 
    { spkiData :: List1 SPKIElement
    } -- ^§4.4.6
  | MgmtData XString -- ^§4.4.7
  | KeyInfoElement Node
  deriving (Eq, Show)

instance XP.XmlPickler KeyInfoElement where
  xpickle = [XP.biCase|
      Left (Left (Left (Left (Left (Left (Left n)))))) <-> KeyName n
      Left (Left (Left (Left (Left (Left (Right v)))))) <-> KeyInfoKeyValue v
      Left (Left (Left (Left (Left (Right ((u, t), f)))))) <-> RetrievalMethod u t f
      Left (Left (Left (Left (Right l)))) <-> X509Data l
      Left (Left (Left (Right ((i, p), x)))) <-> PGPData i p x
      Left (Left (Right l)) <-> SPKIData l
      Left (Right m) <-> MgmtData m
      Right x <-> KeyInfoElement x|]
    XP.>$<  (xpElem "KeyName" XS.xpString
      XP.>|< XP.xpickle
      XP.>|< xpElem "RetrievalMethod"
              (XP.xpAttr "URI" XS.xpAnyURI
        XP.>*< XP.xpAttrImplied "Type" XS.xpAnyURI
        XP.>*< XP.xpOption XP.xpickle)
      XP.>|< xpElem "X509Data" (xpList1 XP.xpickle)
      XP.>|< xpElem "PGPData"
              (XP.xpOption (xpElem "PGPKeyID" XS.xpBase64Binary)
        XP.>*< XP.xpOption (xpElem "PGPKeyPacket" XS.xpBase64Binary)
        XP.>*< XP.xpList xpTrimAnyElem)
      XP.>|< xpElem "SPKIData" (xpList1 XP.xpickle)
      XP.>|< xpElem "MgmtData" XS.xpString
      XP.>|< XP.xpTree)

-- |§4.4.2
data KeyValue
  = DSAKeyValue
    { dsaKeyValuePQ :: Maybe (CryptoBinary, CryptoBinary)
    , dsaKeyValueG :: Maybe CryptoBinary
    , dsaKeyValueY :: CryptoBinary
    , dsaKeyValueJ :: Maybe CryptoBinary
    , dsaKeyValueSeedPgenCounter :: Maybe (CryptoBinary, CryptoBinary)
    } -- ^§4.4.2.1
  | RSAKeyValue
    { rsaKeyValueModulus
    , rsaKeyValueExponent :: CryptoBinary
    } -- ^§4.4.2.2
  | KeyValue Node
  deriving (Eq, Show)

instance XP.XmlPickler KeyValue where
  xpickle = xpElem "KeyValue" $
    [XP.biCase|
      Left (Left ((((pq, g), y), j), sp)) <-> DSAKeyValue pq g y j sp
      Left (Right (m, e)) <-> RSAKeyValue m e
      Right x <-> KeyValue x|]
    XP.>$< (xpElem "DSAKeyValue" 
              (XP.xpOption
                (xpElem "P" xpCryptoBinary
          XP.>*< xpElem "Q" xpCryptoBinary)
        XP.>*< XP.xpOption (xpElem "G" xpCryptoBinary)
        XP.>*< xpElem "Y" xpCryptoBinary
        XP.>*< XP.xpOption (xpElem "J" xpCryptoBinary)
        XP.>*< (XP.xpOption
                (xpElem "Seed" xpCryptoBinary
          XP.>*< xpElem "PgenCounter" xpCryptoBinary)))
      XP.>|< xpElem "RSAKeyValue" 
              (xpElem "Modulus" xpCryptoBinary
        XP.>*< xpElem "Exponent" xpCryptoBinary)
      XP.>|< XP.xpTree)

-- |§4.4.4.1
type X509DistinguishedName = XString

xpX509DistinguishedName :: XP.PU X509DistinguishedName
xpX509DistinguishedName = XS.xpString

data X509Element
  = X509IssuerSerial
    { x509IssuerName :: X509DistinguishedName
    , x509SerialNumber :: Int
    }
  | X509SKI XS.Base64Binary
  | X509SubjectName X509DistinguishedName
  | X509Certificate XS.Base64Binary
  | X509CRL XS.Base64Binary
  | X509Element Node
  deriving (Eq, Show)

instance XP.XmlPickler X509Element where
  xpickle = [XP.biCase|
      Left (Left (Left (Left (Left (n, i))))) <-> X509IssuerSerial n i
      Left (Left (Left (Left (Right n)))) <-> X509SubjectName n
      Left (Left (Left (Right b))) <-> X509SKI b
      Left (Left (Right b)) <-> X509Certificate b
      Left (Right b) <-> X509CRL b
      Right x <-> X509Element x|]
    XP.>$< (xpElem "X509IssuerSerial"
              (xpElem "X509IssuerName" xpX509DistinguishedName
        XP.>*< xpElem "X509SerialNumber" XP.xpickle)
      XP.>|< xpElem "X509SubjectName" xpX509DistinguishedName
      XP.>|< xpElem "X509SKI" XS.xpBase64Binary
      XP.>|< xpElem "X509Certificate" XS.xpBase64Binary
      XP.>|< xpElem "X509CRL" XS.xpBase64Binary
      XP.>|< xpTrimAnyElem)

-- |§4.4.6
data SPKIElement
  = SPKISexp XS.Base64Binary
  | SPKIElement Node
  deriving (Eq, Show)

instance XP.XmlPickler SPKIElement where
  xpickle = [XP.biCase|
      Left b <-> SPKISexp b
      Right x <-> SPKIElement x|]
    XP.>$<  (xpElem "SPKISexp" XS.xpBase64Binary
      XP.>|< xpTrimAnyElem)

-- |§4.5
data Object = Object
  { objectId :: Maybe ID
  , objectMimeType :: Maybe XString
  , objectEncoding :: Maybe (IdentifiedURI EncodingAlgorithm)
  , objectXML :: [ObjectElement]
  } deriving (Eq, Show)

instance XP.XmlPickler Object where
  xpickle = xpElem "Object" $
    [XP.biCase|(((i, m), e), x) <-> Object i m e x|] 
    XP.>$< (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< XP.xpAttrImplied "MimeType" XS.xpString
      XP.>*< XP.xpAttrImplied "Encoding" XP.xpickle
      XP.>*< XP.xpList XP.xpickle)

data ObjectElement
  = ObjectSignature Signature
  | ObjectSignatureProperties SignatureProperties
  | ObjectManifest Manifest
  | ObjectElement Node
  deriving (Eq, Show)

instance XP.XmlPickler ObjectElement where
  xpickle = [XP.biCase|
      Left (Left (Left s)) <-> ObjectSignature s
      Left (Left (Right p)) <-> ObjectSignatureProperties p
      Left (Right m) <-> ObjectManifest m
      Right x <-> ObjectElement x|]
    XP.>$<  (XP.xpickle
      XP.>|< XP.xpickle
      XP.>|< XP.xpickle
      XP.>|< XP.xpTree)

-- |§5.1
data Manifest = Manifest
  { manifestId :: Maybe ID
  , manifestReferences :: List1 Reference
  } deriving (Eq, Show)

instance XP.XmlPickler Manifest where
  xpickle = xpElem "Manifest" $
    [XP.biCase|(i, r) <-> Manifest i r|] 
    XP.>$<  (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< xpList1 XP.xpickle)

-- |§5.2
data SignatureProperties = SignatureProperties
  { signaturePropertiesId :: Maybe ID
  , signatureProperties :: List1 SignatureProperty
  } deriving (Eq, Show)

instance XP.XmlPickler SignatureProperties where
  xpickle = xpElem "SignatureProperties" $
    [XP.biCase|(i, p) <-> SignatureProperties i p|] 
    XP.>$<  (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< xpList1 XP.xpickle)

data SignatureProperty = SignatureProperty
  { signaturePropertyId :: Maybe ID
  , signaturePropertyTarget :: AnyURI
  , signatureProperty :: List1 Node
  } deriving (Eq, Show)

instance XP.XmlPickler SignatureProperty where
  xpickle = xpElem "SignatureProperty" $
    [XP.biCase|((i, t), x) <-> SignatureProperty i t x|] 
    XP.>$<  (XP.xpAttrImplied "Id" XS.xpID
      XP.>*< XP.xpAttr "Target" XS.xpAnyURI
      XP.>*< xpList1 XP.xpTree)

-- |§6.1
data EncodingAlgorithm
  = EncodingBase64
  deriving (Eq, Bounded, Enum, Show)

instance Identifiable URI EncodingAlgorithm where
  identifier EncodingBase64 = nsFrag "base64"

-- |§6.2
data DigestAlgorithm
  = DigestSHA1 -- ^§6.2.1
  | DigestSHA256 -- ^xmlenc §5.7.2
  | DigestSHA512 -- ^xmlenc §5.7.3
  | DigestRIPEMD160 -- ^xmlenc §5.7.4
  deriving (Eq, Bounded, Enum, Show)

instance Identifiable URI DigestAlgorithm where
  identifier DigestSHA1 = nsFrag "sha1"
  identifier DigestSHA256 = httpURI "www.w3.org" "/2001/04/xmlenc" "" "#sha256"
  identifier DigestSHA512 = httpURI "www.w3.org" "/2001/04/xmlenc" "" "#sha512"
  identifier DigestRIPEMD160 = httpURI "www.w3.org" "/2001/04/xmlenc" "" "#ripemd160"

-- |§6.3
data MACAlgorithm
  = MACHMAC_SHA1 -- ^§6.3.1
  deriving (Eq, Bounded, Enum, Show)

instance Identifiable URI MACAlgorithm where
  identifier MACHMAC_SHA1 = nsFrag "hmac-sha1"

-- |§6.4
data SignatureAlgorithm
  = SignatureDSA_SHA1
  | SignatureRSA_SHA1
  deriving (Eq, Bounded, Enum, Show)

instance Identifiable URI SignatureAlgorithm where
  identifier SignatureDSA_SHA1 = nsFrag "dsa-sha1"
  identifier SignatureRSA_SHA1 = nsFrag "rsa-sha1"

-- |§6.6
data TransformAlgorithm
  = TransformCanonicalization C14N.CanonicalizationAlgorithm -- ^§6.6.1
  | TransformBase64 -- ^§6.6.2
  | TransformXPath -- ^§6.6.3
  | TransformEnvelopedSignature -- ^§6.6.4
  | TransformXSLT -- ^§6.6.5
  deriving (Eq, Show)

instance Identifiable URI TransformAlgorithm where
  identifier (TransformCanonicalization c) = identifier c
  identifier TransformBase64 = nsFrag "base64"
  identifier TransformXPath = httpURI "www.w3.org" "/TR/1999/REC-xpath-19991116" "" ""
  identifier TransformEnvelopedSignature = nsFrag "enveloped-signature"
  identifier TransformXSLT = httpURI "www.w3.org" "/TR/1999/REC-xslt-19991116" "" ""
  identifiedValues =
    map TransformCanonicalization identifiedValues ++
    [ TransformBase64
    , TransformXSLT
    , TransformXPath
    , TransformEnvelopedSignature
    ]

data SigningKey
  = SigningKeyDSA DSA.KeyPair
  | SigningKeyRSA RSA.KeyPair
  deriving (Eq, Show)

data PublicKeys = PublicKeys
  { publicKeyDSA :: Maybe DSA.PublicKey
  , publicKeyRSA :: Maybe RSA.PublicKey
  } deriving (Eq, Show)

instance Monoid PublicKeys where
  mempty = PublicKeys Nothing Nothing
  PublicKeys dsa1 rsa1 `mappend` PublicKeys dsa2 rsa2 =
    PublicKeys (dsa1 <|> dsa2) (rsa1 <|> rsa2)

signingKeySignatureAlgorithm :: SigningKey -> SignatureAlgorithm
signingKeySignatureAlgorithm (SigningKeyDSA _) = SignatureDSA_SHA1
signingKeySignatureAlgorithm (SigningKeyRSA _) = SignatureRSA_SHA1

signBase64 :: SigningKey -> BS.ByteString -> IO BS.ByteString
signBase64 sk = fmap Base64.encode . signBytes sk where
  signBytes (SigningKeyDSA k) b = do
    s <- DSA.sign (DSA.toPrivateKey k) SHA1 b
    return $ i2ospOf_ 20 (DSA.sign_r s) <> i2ospOf_ 20 (DSA.sign_s s)
  signBytes (SigningKeyRSA k) b =
    either (fail . show) return =<< RSA.signSafer (Just SHA1) (RSA.toPrivateKey k) b

verifyBase64 :: PublicKeys -> IdentifiedURI SignatureAlgorithm -> BS.ByteString -> BS.ByteString -> Maybe Bool
verifyBase64 pk alg m = either (const $ Just False) (verifyBytes pk alg) . Base64.decode where
  verifyBytes PublicKeys{ publicKeyDSA = Just k } (Identified SignatureDSA_SHA1) sig = Just $
    BS.length sig == 40 &&
    DSA.verify SHA1 k DSA.Signature{ DSA.sign_r = os2ip r, DSA.sign_s = os2ip s } m
    where (r, s) = BS.splitAt 20 sig
  verifyBytes PublicKeys{ publicKeyRSA = Just k } (Identified SignatureRSA_SHA1) sig = Just $
    RSA.verify (Just SHA1) k m sig
  verifyBytes _ _ _ = Nothing

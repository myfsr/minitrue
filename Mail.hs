{-# LANGUAGE NoCPP #-}

module Mail
       ( Address (..)
       , MailBody (..)
       , Mail
       , mailFromTo
       , mailFromToList
       , addHeaders
       , textareaToBody
       ) where

import Prelude
import Data.Monoid ((<>))
import Data.Text
import Network.Mail.Mime (Mail (mailHeaders))
import Network.Mail.SMTP hiding (sendMail)
import Text.Shakespeare.Text
import Text.Hamlet (Html, shamlet)
import Text.Blaze.Html.Renderer.Text (renderHtml)
import Data.ByteString (ByteString)
import Yesod.Form.Fields (Textarea (..))
import qualified Data.Text.Lazy as LT

data MailBody = MailBody { plainBody :: LT.Text
                         , htmlBody :: Html
                         }

wrapPlain :: Maybe Text -> Maybe Text -> Maybe Text -> LT.Text -> LT.Text
wrapPlain mName mUnsub mEvents body = case mUnsub of
  Nothing -> wrapped
  Just unsub -> wrapped <> (sig unsub)
  where body' = case mName of
          Nothing -> body
          Just name -> [lt|Hi #{name},

#{body}|]
        body'' = case mEvents of
                   Nothing -> body'
                   Just events -> [lt|#{body'}

#{events}|]
        wrapped = [lt|#{body''}
-- #
The Ministry of Truth.
|]
        sig unsub = [lt|
To unsubscribe from this mailing list, visit #{unsub}
Um sich aus dieser Mailingliste auszutragen, besuchen Sie #{unsub}|]

wrapHtml :: Maybe Text -> Maybe Text -> Maybe Html -> Html -> Html
wrapHtml mName mUnsub mEvents body = [shamlet|$newline text
$doctype 5
<html>
  <body>
    $maybe name <- mName
      <p>Hi #{name},
    <p>#{body}
    $maybe events <- mEvents
      <div>#{events}
    $nothing
    <p><i>--The Ministry of Truth.</i>
    $maybe unsub <- mUnsub
      <p>
        To unsubscribe from this mailing list, visit <a href=#{unsub}>#{unsub}</a>
        <br>
        Um sich aus dieser Mailingliste auszutragen, besuchen Sie <a href=#{unsub}>#{unsub}</a>.
    $nothing
|]

wrapBody :: Maybe Text -> Maybe Text -> Maybe (Text, Html) -> MailBody -> MailBody
wrapBody mName mUnsub mEvents mail =
   MailBody { plainBody = wrapPlain mName mUnsub (fst <$> mEvents) pb
            , htmlBody = wrapHtml mName mUnsub (snd <$> mEvents) hb
            }
  where pb = plainBody mail
        hb = htmlBody mail

textareaToBody :: Textarea -> MailBody
textareaToBody body = MailBody { plainBody = [lt|#{unTextarea body}|]
                               , htmlBody = [shamlet|#{body}|]
                               }

addHeaders :: [(ByteString, Text)] -> Mail -> Mail
addHeaders headers mail = mail { mailHeaders = newHeaders }
  where newHeaders = mailHeaders mail ++ headers

mailFromTo :: Address -> Address -> Text -> MailBody -> Mail
mailFromTo sender receiver = mailFromTo' sender receiver Nothing Nothing

mailFromToList :: Address -> Address -> Text -> Maybe (Text, Html) -> Text -> MailBody -> Mail
mailFromToList sender receiver unsub = mailFromTo' sender receiver $ Just unsub

mailFromTo' :: Address -> Address -> Maybe Text -> Maybe (Text, Html) -> Text -> MailBody -> Mail
mailFromTo' sender receiver mUnsub mEvents subject body = do
  addHeaders headers $ simpleMail sender [receiver] [] [] subject body'
  where wrapped = wrapBody name mUnsub mEvents body
        body' = [ plainTextPart . plainBody $ wrapped
                , htmlPart . renderHtml . htmlBody $ wrapped
                ]
        name = addressName receiver
        headers = [ ("User-Agent", "The Ministry of Truth (minitrue-0.0.9)")
                  ]

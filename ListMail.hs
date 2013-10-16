module ListMail where

import Import
import Data.Char
import qualified Data.Text as T

canonicalizeListName :: Text -> Text
canonicalizeListName = T.map canonicalize
  where canonicalize c
          | isAsciiUpper c = toLower c
          | isAsciiLower c = c
          | isDigit c = c
          | otherwise = '-'

sendMessageToList :: Message -> MailingListId -> Handler ()
sendMessageToList msg listId = runDB $ do
  addrs <- selectList [MailingListUserList ==. listId] []
  lift $ mapM_ (sendMessageToListUser msg listId) addrs

sendMessageToListUser :: Message -> MailingListId -> Entity MailingListUser -> Handler ()
sendMessageToListUser msg listId (Entity _ mLU) = do
  extra <- getExtra
  renderUrl <- getUrlRender
  (user, list) <- runDB $ do
    usr <- get404 $ mailingListUserUser mLU
    lst <- get404 listId
    return (usr, lst)
  let unsubscribeR key = renderUrl $ UnsubscribeDirectlyR listId key
      sender = mailSenderAddress extra
      subject = T.concat [ "["
                         , mailingListName list
                         , "] "
                         , messageSubject msg
                         ]
      body = textareaToBody . messageBody $ msg
      listid = T.concat [ "<"
                        , canonicalizeListName $ mailingListName list
                        , ".minitrue."
                        , extraMailListIdSuffix extra
                        , ">"
                        ]
      headers key = [ ("List-Id", listid)
                    , ("List-Unsubscribe", unsubscribeR key)
                    ]
      ad = Address Nothing
      message' (addr, key) = mailFromToList sender (ad addr) (unsubscribeR key) subject body
      message ak@(_, key) = sendMail $ addHeaders (headers key) $ message' ak
  message (userEmail user, mailingListUserUnsubkey mLU)
-- | Tradução de 'ErroApp' em resposta HTTP JSON (usada pela API do dashboard, Sprint 4).
--
-- Fica na borda da aplicação: o domínio só conhece 'ErroApp'; aqui ele vira
-- status, cabeçalhos e corpo. A função encerra o tratamento da
-- requisição (como 'forbidden' em "Application.Helper.Auth").
module Application.Helper.Errors
    ( respondErroJson
    ) where

import IHP.ControllerPrelude
import Application.Domain.Erro
import qualified Data.Aeson as Aeson
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai

-- | Responde com JSON: {"erro": {"mensagem": ..., "campos": [{"campo":..., "mensagem":...}]}}.
respondErroJson :: (?request :: Request, ?respond :: Respond) => ErroApp -> IO a
respondErroJson erro = earlyReturn (respondWith (Wai.responseLBS (statusDoErro erro) [(HTTP.hContentType, "application/json; charset=utf-8")] (Aeson.encode (erroParaJson erro))))

erroParaJson :: ErroApp -> Aeson.Value
erroParaJson erro = Aeson.object
    [ "erro" Aeson..= Aeson.object
        [ "mensagem" Aeson..= mensagemUsuario erro
        , "campos" Aeson..= map campoParaJson (camposInvalidos erro)
        ]
    ]

campoParaJson :: ErroCampo -> Aeson.Value
campoParaJson campo = Aeson.object
    [ "campo" Aeson..= erroCampo campo
    , "mensagem" Aeson..= erroMensagem campo
    ]

statusDoErro :: ErroApp -> HTTP.Status
statusDoErro erro = HTTP.mkStatus codigo (frase codigo)
  where
    codigo = statusHttp erro

frase :: Int -> ByteString
frase 403 = "Forbidden"
frase 404 = "Not Found"
frase 409 = "Conflict"
frase 422 = "Unprocessable Entity"
frase 503 = "Service Unavailable"
frase _ = "Internal Server Error"

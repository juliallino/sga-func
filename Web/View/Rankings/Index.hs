module Web.View.Rankings.Index where
import Web.View.Prelude
import Numeric (showFFloat)

data RankingEntry = RankingEntry { position :: Int64, name :: Text, registration :: Text, average :: Double }
data RankingGroup = RankingGroup { title :: Text, entries :: [RankingEntry] }
data IndexView = IndexView { groups :: [RankingGroup], selfOnly :: Bool }
instance View IndexView where
    html IndexView { .. } = [hsx|
        <p class="eyebrow">Resultados acadêmicos</p><h1>Rankings</h1>
        <p>Média ponderada por disciplina. O ranking geral exige média disponível em todas as disciplinas do curso e usa a média simples dessas médias. Ausência não equivale a zero. Empates recebem a mesma posição.</p>
        {when selfOnly privacyNotice}
        {forEach groups renderGroup}
    |]
privacyNotice :: Html
privacyNotice = [hsx|<p class="portal-notice">Você visualiza somente sua própria posição e média. Nenhum resultado de terceiros é exibido.</p>|]
renderGroup :: RankingGroup -> Html
renderGroup group = [hsx|
    <section class="dashboard-section"><h2>{group.title}</h2>
        {when (null group.entries) emptyRanking}
        <div class="table-responsive"><table class="table"><thead><tr><th>Posição</th><th>Estudante</th><th>Registro</th><th>Média</th></tr></thead><tbody>{forEach group.entries renderEntry}</tbody></table></div>
    </section>
|]
renderEntry :: RankingEntry -> Html
renderEntry entry = [hsx|<tr><td>{entry.position}</td><td>{entry.name}</td><td>{entry.registration}</td><td>{cs (showFFloat (Just 2) entry.average "") :: Text}</td></tr>|]
emptyRanking :: Html
emptyRanking = [hsx|<p>Sem média disponível para esta classificação.</p>|]

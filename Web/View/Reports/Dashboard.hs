module Web.View.Reports.Dashboard where
import Prelude (String)
import Web.View.Prelude
import Numeric (showFFloat)
import Application.Domain.Erro (ErroCampo (..))
import qualified Application.Domain.Report as Report

-- View mínima do dashboard (SSR com HSX). O formulário usa GET: o filtro fica
-- na URL e pode ser compartilhado. As restrições HTML (min, max, maxlength)
-- dão a validação no cliente; o servidor valida novamente em
-- Report.validarFiltro, e os erros voltam em "errosFiltro".
data DashboardView = DashboardView
    { relatorio :: Report.Relatorio
    , valores :: Report.ParamsFiltro
    , errosFiltro :: [ErroCampo]
    , cursos :: [Course]
    }

instance View DashboardView where
    html DashboardView { .. } = [hsx|
        <p class="eyebrow">Administração</p><h1>Relatórios de desempenho</h1>
        <p class="page-description">Médias ponderadas por matrícula, com filtros, ranking e distribuição.</p>
        {forEach errosFiltro renderErroFiltro}
        {renderFiltros valores cursos}
        {renderResumo (Report.relResumo relatorio)}
        <h2>Ranking</h2>
        {when (null (Report.relRanking relatorio)) semDados}
        <div class="table-responsive"><table class="table"><thead><tr><th>#</th><th>Aluno</th><th>Curso</th><th>Média</th></tr></thead><tbody>{forEach (Report.relRanking relatorio) renderPosicao}</tbody></table></div>
        <h2>Médias por curso</h2>
        <div class="table-responsive"><table class="table"><thead><tr><th>Curso</th><th>Matrículas</th><th>Média do curso</th><th>Melhor média</th></tr></thead><tbody>{forEach (Report.relPorCurso relatorio) renderCurso}</tbody></table></div>
        <h2>Distribuição das médias</h2>
        <div class="table-responsive"><table class="table"><thead><tr><th>Faixa</th><th>Matrículas</th></tr></thead><tbody>{forEach (Report.relDistribuicao relatorio) renderFaixa}</tbody></table></div>
    |]

renderErroFiltro :: ErroCampo -> Html
renderErroFiltro erro = [hsx|<div class="alert alert-danger" role="alert">{erroMensagem erro}</div>|]

semDados :: Html
semDados = [hsx|<p class="portal-notice">Nenhuma matrícula com média para os filtros informados.</p>|]

renderFiltros :: Report.ParamsFiltro -> [Course] -> Html
renderFiltros valores cursos = [hsx|
    <form method="GET" action={pathTo DashboardAction} class="row g-2 mb-4">
        <div class="col-md-3">
            <label class="form-label" for="courseId">Curso</label>
            <select class="form-select" id="courseId" name="courseId">
                <option value="">Todos</option>
                {forEach cursos (renderOpcaoCurso (Report.pfCurso valores))}
            </select>
        </div>
        <div class="col-md-2">
            <label class="form-label" for="status">Situação</label>
            <select class="form-select" id="status" name="status">
                <option value="">Todas</option>
                {opcaoStatus (Report.pfStatus valores) "active" "Ativa"}
                {opcaoStatus (Report.pfStatus valores) "suspended" "Suspensa"}
                {opcaoStatus (Report.pfStatus valores) "completed" "Concluída"}
            </select>
        </div>
        <div class="col-md-2">
            <label class="form-label" for="minAverage">Média mínima</label>
            <input class="form-control" type="number" min="0" max="10" step="0.01" id="minAverage" name="minAverage" value={textoOu (Report.pfMediaMinima valores)}/>
        </div>
        <div class="col-md-3">
            <label class="form-label" for="q">Buscar aluno ou curso</label>
            <input class="form-control" type="text" maxlength="100" id="q" name="q" value={textoOu (Report.pfBusca valores)}/>
        </div>
        <div class="col-md-1">
            <label class="form-label" for="top">Top</label>
            <input class="form-control" type="number" min="1" max="100" step="1" id="top" name="top" value={textoOu (Report.pfLimite valores)}/>
        </div>
        <div class="col-md-1 d-flex align-items-end">
            <button class="btn btn-primary w-100" type="submit">Filtrar</button>
        </div>
    </form>
|]

renderOpcaoCurso :: Maybe String -> Course -> Html
renderOpcaoCurso escolhido course = [hsx|<option value={cursoId} selected={fmap cs escolhido == Just cursoId}>{course.name}</option>|]
    where cursoId = cs (show course.id) :: Text

opcaoStatus :: Maybe String -> Text -> Text -> Html
opcaoStatus escolhido valor rotulo = [hsx|<option value={valor} selected={fmap cs escolhido == Just valor}>{rotulo}</option>|]

textoOu :: Maybe String -> Text
textoOu = maybe "" cs

renderResumo :: Report.ResumoGeral -> Html
renderResumo resumo = [hsx|
    <div class="row g-3 mb-4">
        {cartao "Matrículas" (show (Report.rgMatriculas resumo))}
        {cartao "Com média" (show (Report.rgComMedia resumo))}
        {cartao "Sem média" (show (Report.rgSemMedia resumo))}
        {cartao "Média geral" (formatarMedia (Report.rgMediaGeral resumo))}
    </div>
|]

cartao :: Text -> Text -> Html
cartao rotulo valor = [hsx|
    <div class="col-6 col-md-3"><div class="border rounded p-3"><div class="text-muted small">{rotulo}</div><div class="fs-3">{valor}</div></div></div>
|]

renderPosicao :: Report.PosicaoRanking -> Html
renderPosicao posicao = [hsx|
    <tr><td>{Report.prPosicao posicao}</td><td>{Report.prAluno posicao}</td><td>{Report.prCurso posicao}</td><td>{formatarMedia (Just (Report.prMedia posicao))}</td></tr>
|]

renderCurso :: Report.ResumoCurso -> Html
renderCurso curso = [hsx|
    <tr><td>{Report.rcCurso curso}</td><td>{Report.rcMatriculas curso}</td><td>{formatarMedia (Report.rcMediaCurso curso)}</td><td>{formatarMedia (Report.rcMelhorMedia curso)}</td></tr>
|]

renderFaixa :: Report.FaixaNota -> Html
renderFaixa faixa = [hsx|
    <tr><td>{Report.fnRotulo faixa}</td><td>{Report.fnQuantidade faixa}</td></tr>
|]

formatarMedia :: Maybe Double -> Text
formatarMedia (Just valor) = cs (showFFloat (Just 2) valor "")
formatarMedia Nothing = "—"

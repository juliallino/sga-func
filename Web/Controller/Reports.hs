module Web.Controller.Reports where

import Prelude (String)
import Web.Controller.Prelude
import Web.View.Reports.Dashboard
import Application.Domain.Erro (ErroCampo)
import Application.Helper.Errors (respondErroJson)
import qualified Application.Domain.Report as Report
import qualified Data.Aeson as Aeson
import qualified Data.Map.Strict as Map
import qualified Data.Maybe as Maybe

-- Camada imperativa fina: lê parâmetros, carrega dados, chama o núcleo puro
-- (Application.Domain.Report) e responde. Somente Admin: o ranking expõe
-- dados de vários estudantes.
instance Controller ReportsController where
    action DashboardAction = do
        requireAdmin
        let valores = paramsFiltro
        let (filtro, errosFiltro) = Report.resolverFiltro valores
        linhas <- carregarLinhas
        cursos <- query @Course |> orderBy #name |> fetch
        let relatorio = Report.gerarRelatorio filtro linhas
        render DashboardView { .. }

    action DashboardDataAction = do
        requireAdmin
        -- Filtro inválido: 422 com a lista de campos (validação no servidor).
        case Report.prepararConsulta paramsFiltro of
            Left erro -> respondErroJson erro
            Right filtro -> do
                linhas <- carregarLinhas
                renderJson (relatorioJson (Report.gerarRelatorio filtro linhas))

-- Parâmetros de consulta: courseId, status, minAverage, q e top.
paramsFiltro :: (?request :: Request) => Report.ParamsFiltro
paramsFiltro = Report.ParamsFiltro
    { Report.pfCurso = parametro "courseId"
    , Report.pfStatus = parametro "status"
    , Report.pfMediaMinima = parametro "minAverage"
    , Report.pfBusca = parametro "q"
    , Report.pfLimite = parametro "top"
    }

parametro :: (?request :: Request) => ByteString -> Maybe String
parametro nome = fmap cs (paramOrNothing @Text nome)

-- Uma leitura por tabela e agrupamento em Map: custo linear no número de
-- registros, sem consultas por matrícula (N+1).
carregarLinhas :: (?modelContext :: ModelContext) => IO [Report.LinhaDesempenho]
carregarLinhas = do
    enrollments <- query @Enrollment |> fetch
    students <- query @Student |> fetch
    courses <- query @Course |> fetch
    grades <- query @Grade |> fetch
    let alunos = Map.fromList [(unpackId student.id, student) | student <- students]
    let cursos = Map.fromList [(unpackId course.id, course) | course <- courses]
    let avaliacoes = Map.fromListWith (++)
            [(grade.enrollmentId, [(realToFrac grade.score, realToFrac grade.weight) :: (Double, Double)]) | grade <- grades]
    pure (Maybe.mapMaybe (linhaDaMatricula alunos cursos avaliacoes) enrollments)

linhaDaMatricula :: Map.Map UUID Student -> Map.Map UUID Course -> Map.Map UUID [(Double, Double)] -> Enrollment -> Maybe Report.LinhaDesempenho
linhaDaMatricula alunos cursos avaliacoes enrollment = do
    student <- Map.lookup enrollment.studentId alunos
    course <- Map.lookup enrollment.courseId cursos
    pure Report.LinhaDesempenho
        { Report.ldMatricula = cs (show enrollment.id)
        , Report.ldAlunoId = cs (show student.id)
        , Report.ldAluno = cs student.name
        , Report.ldCursoId = cs (show course.id)
        , Report.ldCurso = cs course.name
        , Report.ldStatus = statusDaMatricula enrollment.status
        , Report.ldAvaliacoes = Map.findWithDefault [] (unpackId enrollment.id) avaliacoes
        }

statusDaMatricula :: EnrollmentStatus -> Report.StatusMatricula
statusDaMatricula Active = Report.MatriculaAtiva
statusDaMatricula Suspended = Report.MatriculaSuspensa
statusDaMatricula Completed = Report.MatriculaConcluida

-- Contrato JSON de GET /ReportsData.
relatorioJson :: Report.Relatorio -> Aeson.Value
relatorioJson relatorio = Aeson.object
    [ "resumo" Aeson..= resumoJson (Report.relResumo relatorio)
    , "porCurso" Aeson..= map cursoJson (Report.relPorCurso relatorio)
    , "ranking" Aeson..= map posicaoJson (Report.relRanking relatorio)
    , "distribuicao" Aeson..= map faixaJson (Report.relDistribuicao relatorio)
    ]

resumoJson :: Report.ResumoGeral -> Aeson.Value
resumoJson resumo = Aeson.object
    [ "matriculas" Aeson..= Report.rgMatriculas resumo
    , "comMedia" Aeson..= Report.rgComMedia resumo
    , "semMedia" Aeson..= Report.rgSemMedia resumo
    , "mediaGeral" Aeson..= Report.rgMediaGeral resumo
    , "maiorMedia" Aeson..= Report.rgMaiorMedia resumo
    , "menorMedia" Aeson..= Report.rgMenorMedia resumo
    ]

cursoJson :: Report.ResumoCurso -> Aeson.Value
cursoJson curso = Aeson.object
    [ "cursoId" Aeson..= Report.rcCursoId curso
    , "curso" Aeson..= Report.rcCurso curso
    , "matriculas" Aeson..= Report.rcMatriculas curso
    , "mediaCurso" Aeson..= Report.rcMediaCurso curso
    , "melhorMedia" Aeson..= Report.rcMelhorMedia curso
    ]

posicaoJson :: Report.PosicaoRanking -> Aeson.Value
posicaoJson posicao = Aeson.object
    [ "posicao" Aeson..= Report.prPosicao posicao
    , "matricula" Aeson..= Report.prMatricula posicao
    , "aluno" Aeson..= Report.prAluno posicao
    , "curso" Aeson..= Report.prCurso posicao
    , "media" Aeson..= Report.prMedia posicao
    ]

faixaJson :: Report.FaixaNota -> Aeson.Value
faixaJson faixa = Aeson.object
    [ "faixa" Aeson..= Report.fnRotulo faixa
    , "minimo" Aeson..= Report.fnMinimo faixa
    , "maximo" Aeson..= Report.fnMaximo faixa
    , "quantidade" Aeson..= Report.fnQuantidade faixa
    ]

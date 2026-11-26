module Web.View.AcademicPeriods.Index where

import Web.View.Prelude
import Web.View.ClassSessions.Form (formatDay)

data IndexView = IndexView
    { academicPeriods :: [AcademicPeriod]
    , enrollmentCounts :: [(UUID, Int)]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        {breadcrumb}
        <h1>Períodos letivos<a href={pathTo NewAcademicPeriodAction} class="btn btn-primary ms-4">+ Novo período</a></h1>
        <p class="page-description">Semestres no formato 2026.1 e 2026.2. Cada matrícula pertence a um período, e o estudante pode refazer uma disciplina em outro período.</p>
        {when (null academicPeriods) (emptyState "periods" "Nenhum período cadastrado" "Cadastre os semestres para organizar as matrículas por período.")}
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th scope="col">Período</th>
                        <th scope="col">Início</th>
                        <th scope="col">Fim</th>
                        <th scope="col">Matrículas</th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                        <th scope="col"><span class="visually-hidden">Ações</span></th>
                    </tr>
                </thead>
                <tbody>{forEach academicPeriods (renderPeriod enrollmentCounts)}</tbody>
            </table>
        </div>
    |]
        where
            breadcrumb = renderBreadcrumb [ breadcrumbLink "Períodos" AcademicPeriodsAction ]

renderPeriod :: [(UUID, Int)] -> AcademicPeriod -> Html
renderPeriod enrollmentCounts academicPeriod = [hsx|
    <tr>
        <td>{academicPeriod.name}</td>
        <td>{formatDay academicPeriod.startsOn}</td>
        <td>{formatDay academicPeriod.endsOn}</td>
        <td>{enrollmentCount}</td>
        <td><a href={EditAcademicPeriodAction academicPeriod.id} class="text-muted">Editar</a></td>
        <td><a href={DeleteAcademicPeriodAction academicPeriod.id} class="js-delete text-muted" data-confirm="Deseja realmente excluir este período?">Excluir</a></td>
    </tr>
|]
    where
        enrollmentCount = maybe 0 snd (find (\(periodUuid, _) -> periodUuid == unpackId academicPeriod.id) enrollmentCounts)

module Web.View.AcademicPeriods.Form (renderForm) where

import Web.View.Prelude

renderForm :: (?request :: Request) => AcademicPeriod -> Html
renderForm academicPeriod = formFor academicPeriod [hsx|
    {(textField #name) { fieldLabel = "Período", placeholder = "2026.1", helpText = "Formato ano.semestre: 2026.1 (primeiro semestre) ou 2026.2 (segundo semestre).", required = True }}
    {(dateField #startsOn) { fieldLabel = "Início das aulas", required = True }}
    {(dateField #endsOn) { fieldLabel = "Fim das aulas", required = True }}
    {formActions (submitButton { label = "Salvar" }) (pathTo AcademicPeriodsAction)}
|]

module Web.View.AcademicPeriods.New where

import Web.View.Prelude
import Web.View.AcademicPeriods.Form (renderForm)

data NewView = NewView { academicPeriod :: AcademicPeriod }

instance View NewView where
    html NewView { .. } = [hsx|
        {breadcrumb}
        <h1>Novo período letivo</h1>
        {renderForm academicPeriod}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Períodos" AcademicPeriodsAction
                , breadcrumbText "Novo período"
                ]

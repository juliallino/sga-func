module Web.View.AcademicPeriods.Edit where

import Web.View.Prelude
import Web.View.AcademicPeriods.Form (renderForm)

data EditView = EditView { academicPeriod :: AcademicPeriod }

instance View EditView where
    html EditView { .. } = [hsx|
        {breadcrumb}
        <h1>Editar período {academicPeriod.name}</h1>
        {renderForm academicPeriod}
    |]
        where
            breadcrumb = renderBreadcrumb
                [ breadcrumbLink "Períodos" AcademicPeriodsAction
                , breadcrumbText "Editar período"
                ]

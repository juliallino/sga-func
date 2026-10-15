module Application.Helper.View where

import IHP.ViewPrelude
import Generated.Types

-- Here you can add functions which are available in all your views

enrollmentStatusLabel :: EnrollmentStatus -> Text
enrollmentStatusLabel Active = "Ativa"
enrollmentStatusLabel Suspended = "Suspensa"
enrollmentStatusLabel Completed = "Concluída"

instance CanSelect EnrollmentStatus where
    type SelectValue EnrollmentStatus = EnrollmentStatus
    selectValue status = status
    selectLabel = enrollmentStatusLabel

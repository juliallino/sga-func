module Application.Helper.View where

import IHP.ViewPrelude
import Generated.Types
import Application.Auth.Types ()

-- Here you can add functions which are available in all your views

enrollmentStatusLabel :: EnrollmentStatus -> Text
enrollmentStatusLabel Active = "Ativa"
enrollmentStatusLabel Suspended = "Suspensa"
enrollmentStatusLabel Completed = "Concluída"

instance CanSelect EnrollmentStatus where
    type SelectValue EnrollmentStatus = EnrollmentStatus
    selectValue status = status
    selectLabel = enrollmentStatusLabel

-- Shared by enrollment and subject forms (relationSupport = false).
instance CanSelect Course where
    type SelectValue Course = UUID
    selectLabel course = course.name <> " - " <> course.code
    selectValue course = unpackId course.id

-- Presentation follows the server policy; these helpers never replace guards.
isAdmin :: (?request :: Request) => Bool
isAdmin = maybe False ((== Roleadmin) . (.role_)) (currentUserOrNothing @User)

isStudent :: (?request :: Request) => Bool
isStudent = maybe False ((== Rolestudent) . (.role_)) (currentUserOrNothing @User)

isTeacher :: (?request :: Request) => Bool
isTeacher = maybe False ((== Roleteacher) . (.role_)) (currentUserOrNothing @User)

roleLabel :: UserRole -> Text
roleLabel Roleadmin = "Administração"
roleLabel Roleteacher = "Professor"
roleLabel Rolestudent = "Estudante"

-- Local SVG icons: no icon font, remote requests or extra dependencies.
moduleIcon :: Text -> Html
moduleIcon name = [hsx|
    <svg class="module-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d={iconPath name}/>
    </svg>
|]

iconPath :: Text -> Text
iconPath "dashboard" = "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z"
iconPath "students" = "M3 8l9-5 9 5-9 5-9-5 M6 10v7c4 3 8 3 12 0v-7 M21 8v8"
iconPath "teachers" = "M9 8a3 3 0 1 0 6 0 3 3 0 0 0-6 0 M5 21v-3a7 7 0 0 1 14 0v3 M3 3h18"
iconPath "courses" = "M4 4h7v16H4z M14 4h6v16h-6z M6 8h3 M16 8h2"
iconPath "subjects" = "M12 5c-3-2-6-2-9-1v15c3-1 6-1 9 1 3-2 6-2 9-1V4c-3-1-6-1-9 1v15"
iconPath "enrollments" = "M8 4H5v17h14V4h-3 M8 2h8v5H8z M8 12h8 M8 16h5"
iconPath "grades" = "M5 3h14v18H5z M8 8h8 M8 12h4 M8 16h8"
iconPath "users" = "M8 7a4 4 0 1 0 8 0 4 4 0 0 0-8 0 M4 21v-2a8 8 0 0 1 16 0v2"
iconPath "logout" = "M9 4H4v16h5 M13 8l4 4-4 4 M8 12h12"
iconPath _ = "M12 3v18 M3 12h18"

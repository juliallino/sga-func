module Web.View.Grades.Form (EnrollmentOption (..), buildEnrollmentOptions, renderForm) where

import Web.View.Prelude

data EnrollmentOption = EnrollmentOption
    { optionId :: UUID
    , optionLabel :: Text
    }

instance CanSelect EnrollmentOption where
    type SelectValue EnrollmentOption = UUID
    selectValue = (.optionId)
    selectLabel = (.optionLabel)

buildEnrollmentOptions :: [Enrollment] -> [Student] -> [Course] -> [EnrollmentOption]
buildEnrollmentOptions enrollments students courses = map toOption enrollments
    where
        toOption enrollment = EnrollmentOption
            { optionId = unpackId enrollment.id
            , optionLabel = studentLabel enrollment <> " — " <> courseLabel enrollment
            }
        studentLabel enrollment = case find (\student -> unpackId student.id == enrollment.studentId) students of
            Just student -> student.name <> " (" <> student.enrollmentNumber <> ")"
            Nothing -> "Estudante indisponível"
        courseLabel enrollment = case find (\course -> unpackId course.id == enrollment.courseId) courses of
            Just course -> course.name <> " (" <> course.code <> ")"
            Nothing -> "Curso indisponível"

renderForm :: Grade -> [EnrollmentOption] -> Html
renderForm grade enrollmentOptions = formFor grade [hsx|
    {(selectField #enrollmentId enrollmentOptions)
        { fieldLabel = "Matrícula", placeholder = "Selecione uma matrícula", required = True }}
    {when (null enrollmentOptions) noEnrollments}
    {(textField #assessmentName) { fieldLabel = "Nome da avaliação" }}
    {(numberField #score) { fieldLabel = "Nota", additionalAttributes = [("step", "0.01"), ("min", "0"), ("max", "10")] }}
    {(numberField #weight) { fieldLabel = "Peso", additionalAttributes = [("step", "0.01"), ("min", "0.01")] }}
    {submitButton { label = "Salvar" }}
|]

noEnrollments :: Html
noEnrollments = [hsx|
    <p>Nenhuma matrícula cadastrada. <a href={NewEnrollmentAction}>Cadastrar matrícula</a></p>
|]

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

buildEnrollmentOptions :: [Enrollment] -> [Student] -> [Subject] -> [EnrollmentOption]
buildEnrollmentOptions enrollments students subjects = map toOption enrollments
    where
        toOption enrollment = EnrollmentOption
            { optionId = unpackId enrollment.id
            , optionLabel = studentLabel enrollment <> " — " <> subjectLabel enrollment
            }
        studentLabel enrollment = case find (\student -> unpackId student.id == enrollment.studentId) students of
            Just student -> student.name <> " (" <> student.enrollmentNumber <> ")"
            Nothing -> "Estudante indisponível"
        subjectLabel enrollment = case find (\subject -> unpackId subject.id == enrollment.subjectId) subjects of
            Just subject -> subject.name <> " (" <> subject.code <> ")"
            Nothing -> "Disciplina indisponível"

renderForm :: Grade -> [EnrollmentOption] -> Html
renderForm grade enrollmentOptions = formFor grade [hsx|
    {(selectField #enrollmentId enrollmentOptions)
        { fieldLabel = "Matrícula", placeholder = "Selecione uma matrícula", required = True }}
    {when (null enrollmentOptions) noEnrollments}
    {(textField #assessmentName) { fieldLabel = "Nome da avaliação" }}
    {(numberField #score) { fieldLabel = "Nota", additionalAttributes = [("step", "0.01"), ("min", "0"), ("max", "10")] }}
    {(numberField #weight) { fieldLabel = "Peso", additionalAttributes = [("step", "0.01"), ("min", "0.01")] }}
    {formActions (submitButton { label = "Salvar" }) (pathTo GradesAction)}
|]

noEnrollments :: Html
noEnrollments = [hsx|
    <p>Nenhuma matrícula cadastrada. <a href={NewEnrollmentAction}>Cadastrar matrícula</a></p>
|]

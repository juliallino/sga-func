module Web.Controller.Courses where

import Web.Controller.Prelude
import Web.View.Courses.Index
import Web.View.Courses.New
import Web.View.Courses.Edit
import Web.View.Courses.Show

instance Controller CoursesController where
    action CoursesAction = do
        courses <- query @Course |> fetch
        render IndexView { .. }

    action NewCourseAction = do
        let course = newRecord
        render NewView { .. }

    action ShowCourseAction { courseId } = do
        course <- fetchOr404 courseId
        render ShowView { .. }

    action EditCourseAction { courseId } = do
        course <- fetchOr404 courseId
        render EditView { .. }

    action UpdateCourseAction { courseId } = do
        course <- fetchOr404 courseId
        let courseValidado = buildCourse course

        courseComCodigoValidado <-
            withCustomErrorMessageIO
                "Este código de curso já está cadastrado"
                validateIsUnique
                #code
                courseValidado

        ifValid (\case
            Left course -> render EditView { .. }
            Right course -> do
                course <- course |> updateRecord
                setSuccessMessage "Curso atualizado com sucesso."
                redirectTo EditCourseAction { .. }
            ) courseComCodigoValidado

    action CreateCourseAction = do
        let course = newRecord @Course
        let courseValidado = buildCourse course

        courseComCodigoValidado <-
            withCustomErrorMessageIO
                "Este código de curso já está cadastrado"
                validateIsUnique
                #code
                courseValidado

        ifValid (\case
            Left course -> render NewView { .. }
            Right course -> do
                course <- course |> createRecord
                setSuccessMessage "Curso cadastrado com sucesso."
                redirectTo CoursesAction
            ) courseComCodigoValidado

    action DeleteCourseAction { courseId } = do
        course <- fetchOr404 courseId
        dependencias <- query @Enrollment
            |> filterWhere (#courseId, unpackId courseId)
            |> fetchOneOrNothing
        if isJust dependencias
            then setErrorMessage "Não é possível excluir um curso com matrículas."
            else do
                deleteRecord course
                setSuccessMessage "Curso excluído com sucesso."
        redirectTo CoursesAction

buildCourse course = course
    |> fill @'["name", "code", "workload"]
    |> validateField #name (withCustomErrorMessage "Informe o nome." nonEmpty)
    |> validateField #code (withCustomErrorMessage "Informe o código." nonEmpty)
    |> validateField #workload (withCustomErrorMessage "A carga horária deve ser maior que zero." (isGreaterThan 0))

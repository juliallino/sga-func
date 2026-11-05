module Main where

import IHP.Prelude
import IHP.ControllerPrelude
import IHP.Test.Mocking
import IHP.Hspec
import IHP.AuthSupport.Authentication (verifyPassword)
import qualified Network.HTTP.Types as HTTP
import qualified Network.Wai as Wai
import qualified Network.Wai.Test as WT
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import qualified Data.List as List
import qualified System.Environment as Env
import Config
import Generated.Types
import Web.Types
import Web.FrontController ()
import Test.Hspec

instance FrontController RootApplication where
    controllers = [mountFrontController WebApplication]

main :: IO ()
main = do
    marker <- Env.getEnv "SGA_ISOLATED_SEED_TEST"
    url <- Env.getEnv "DATABASE_URL"
    unless (marker == "1" && "postgresql:///sga_demo_seed?host=/tmp/sga-seed-test-" `Text.isPrefixOf` cs url) (error "Use somente o executor de seed isolado")
    adminPassword <- cs <$> Env.getEnv "SGA_DEMO_ADMIN_PASSWORD"
    teacherPassword <- cs <$> Env.getEnv "SGA_DEMO_TEACHER_PASSWORD"
    studentPassword <- cs <$> Env.getEnv "SGA_DEMO_STUDENT_PASSWORD"
    rows <- map (Text.splitOn ",") . drop 1 . Text.lines <$> TextIO.readFile "docs/database/reorganizacao-demo-novos-estudantes.csv"
    withMockContext WebApplication config \context -> do
      app <- initTestApplication context
      withContext (do
        students <- query @Student |> orderByAsc #enrollmentNumber |> fetch
        teachers <- query @Teacher |> orderByAsc #registrationNumber |> fetch
        subjects <- query @Subject |> fetch
        users <- query @User |> fetch
        permissions <- query @TeacherSubject |> fetch
        let account userId = fromMaybe (error "Conta vinculada ausente") (find (\u -> Just (unpackId u.id) == userId) users)
        let studentAccounts = map (account . (.userId)) students
        let teacherAccounts = map (account . (.userId)) teachers
        let admin = fromMaybe (error "Admin demo ausente") (find (\u -> u.email == "admin.demo@example.test") users)
        let login email password destination = WT.runSession (do
                let credentials = cs (HTTP.renderSimpleQuery False [("email",cs email),("password",cs password)])
                _ <- WT.srequest (WT.SRequest ((WT.setPath Wai.defaultRequest "/Login") {Wai.requestMethod="POST",Wai.requestHeaders=[(HTTP.hContentType,"application/x-www-form-urlencoded")]}) credentials)
                WT.request (WT.setPath Wai.defaultRequest destination)) app
        hspec do
          describe "Seed portátil: identidades e integridade" do
            it "cria as quantidades acadêmicas e três perfis" do
              query @Course |> fetchCount >>= (`shouldBe` 1)
              length subjects `shouldBe` 5
              length teachers `shouldBe` 5
              length permissions `shouldBe` 5
              length students `shouldBe` 10
              length users `shouldBe` 16
              query @Enrollment |> fetchCount >>= (`shouldBe` 50)
              query @Grade |> fetchCount >>= (`shouldBe` 120)
              admin.role_ `shouldBe` Roleadmin
              map (.role_) studentAccounts `shouldBe` replicate 10 Rolestudent
              map (.role_) teacherAccounts `shouldBe` replicate 5 Roleteacher
            it "usa os dez nomes/e-mails publicados e mantém students/users consistentes" do
              map (.name) students `shouldBe` ["Pedro Lino","Ana Beatriz","Lucas Oliveira","Mariana Costa","Gabriel Almeida","Sofia Martins","Rafael Ferreira","Julia Santos","Felipe Rocha","Camila Ribeiro"]
              forEach (zip rows students) \(row, student) -> do
                student.enrollmentNumber `shouldBe` row !! 0
                student.name `shouldBe` row !! 1
                student.email `shouldBe` row !! 2
                let user = account student.userId
                user.name `shouldBe` student.name
                user.email `shouldBe` student.email
            it "cada estudante tem cinco disciplinas, sem vínculos órfãos" do
              forEach students \student -> do
                enrollments <- query @Enrollment |> filterWhere (#studentId,unpackId student.id) |> fetch
                length enrollments `shouldBe` 5
                length (nub (map (.subjectId) enrollments)) `shouldBe` 5
                mapM_ (\e -> (any (\s -> unpackId s.id == e.subjectId) subjects) `shouldBe` True) enrollments
            it "cada disciplina tem dez matrículas, 24 avaliações e duas matrículas sem nota" do
              forEach subjects \subject -> do
                enrollments <- query @Enrollment |> filterWhere (#subjectId,unpackId subject.id) |> fetch
                grades <- query @Grade |> filterWhereIn (#enrollmentId,map (unpackId . (.id)) enrollments) |> fetch
                length enrollments `shouldBe` 10
                length grades `shouldBe` 24
                length (filter (\e -> not (any (\g -> g.enrollmentId == unpackId e.id) grades)) enrollments) `shouldBe` 2
          describe "Seed: credenciais locais e permissões reais" do
            it "usa hashes verificáveis com salt próprio, sem senha no banco ou hash nos resultados" do
              forEach studentAccounts (\u -> verifyPassword u studentPassword `shouldBe` True)
              forEach teacherAccounts (\u -> verifyPassword u teacherPassword `shouldBe` True)
              verifyPassword admin adminPassword `shouldBe` True
              length (nub (map (.passwordHash) studentAccounts)) `shouldBe` 10
              all (\u -> Text.isPrefixOf "sha256|17|" u.passwordHash && u.passwordHash /= studentPassword) studentAccounts `shouldBe` True
            it "Admin faz login e consulta áreas administrativas" do
              response <- login admin.email adminPassword "/Users"
              WT.simpleStatus response `shouldBe` HTTP.status200
              withUser admin do
                callAction TeachersAction >>= (\r -> responseStatusShouldBe r HTTP.status200)
            it "os dez estudantes fazem login com seus novos e-mails" do
              forEach studentAccounts \user -> do
                response <- login user.email studentPassword "/StudentDashboard"
                WT.simpleStatus response `shouldBe` HTTP.status200
                WT.simpleBody response `shouldSatisfy` (List.isInfixOf (Text.unpack user.name) . cs)
            it "estudantes não veem colegas nem áreas administrativas e não escrevem notas" do
              forEach students \student -> withUser (account student.userId) do
                response <- callAction StudentDashboardAction
                forEach (filter (\s -> s.id /= student.id) students) (\s -> responseBodyShouldNotContain response s.name)
                callAction UsersAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                callAction NewGradeAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
                let other = fromMaybe (error "Outro estudante ausente") (find (\s -> s.id /= student.id) students)
                callAction (ShowStudentAction other.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
            it "cinco professores fazem login e só consultam disciplinas autorizadas" do
              forEach teachers \teacher -> do
                let user = account teacher.userId
                response <- login user.email teacherPassword "/TeacherDashboard"
                WT.simpleStatus response `shouldBe` HTTP.status200
                withUser user do
                  let permission = fromMaybe (error "Atribuição ausente") (find (\p -> p.teacherId == unpackId teacher.id) permissions)
                  allowed <- fetch (Id permission.subjectId :: Id Subject)
                  listing <- callAction (TeacherSubjectStudentsAction allowed.id)
                  responseStatusShouldBe listing HTTP.status200
                  forEach students (\s -> responseBodyShouldContain listing s.enrollmentNumber)
                  let other = fromMaybe (error "Disciplina externa ausente") (find (\s -> unpackId s.id /= permission.subjectId) subjects)
                  callAction (TeacherSubjectStudentsAction other.id) >>= (\r -> responseStatusShouldBe r HTTP.status404)
                  callAction NewGradeAction >>= (\r -> responseStatusShouldBe r HTTP.status200)
                  callAction UsersAction >>= (\r -> responseStatusShouldBe r HTTP.status403)
            it "visitantes não acessam o portal estudantil" do
              response <- WT.runSession (WT.request (WT.setPath Wai.defaultRequest "/StudentDashboard")) app
              WT.simpleStatus response `shouldBe` HTTP.status302
        ) context

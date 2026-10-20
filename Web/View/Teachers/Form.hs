module Web.View.Teachers.Form (renderForm) where
import Web.View.Prelude

renderForm :: Teacher -> Html
renderForm teacher = formFor teacher [hsx|
    {(textField #name) { fieldLabel = "Nome" }}
    {(textField #email) { fieldLabel = "E-mail" }}
    {(textField #registrationNumber) { fieldLabel = "Número de registro" }}
    {(textField #specialization) { fieldLabel = "Especialização (opcional)" }}
    {submitButton { label = "Salvar" }}

|]

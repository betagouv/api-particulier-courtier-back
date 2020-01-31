# Backend de signup.api.gouv.fr

Les instructions d'installation se trouve ici : https://github.com/betagouv/signup-ansible

## How to enroll a new API

Here are the files you need to create :
- app/policies/enrollment/<name_of_api>_policy.rb (define permitted additional data)
- app/models/enrollment/<name_of_api>.rb (define additional data validation)

Here are the files you need to update :
- app/mailers/enrollment_mailer.rb (configure sender and api label for mails)
- (optional) app/models/enrollment.rb (L51) (register post validation hook)

You must also allow signup to use the new sender email on mailjet (ask Raphaël).

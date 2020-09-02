class ApplicationMailer < ActionMailer::Base
  default from: 'do-not-reply@simpleappcameroon.com'
  layout 'mailer'
  
  helper SimpleServerEnvHelper
end

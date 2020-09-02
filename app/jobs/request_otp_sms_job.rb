class RequestOtpSmsJob < ApplicationJob
  queue_as :default
  self.queue_adapter = :sidekiq
  
  def perform(user)
    otp_message = otp_message(user)
    AdminNotificationsMailer.send_otp({ phone: user.phone_number, otp: otp_message })
    NotificationService.new.send_sms(user.phone_number, otp_message)
  end
  
  private
  
  def otp_message(user)
    app_signature = ENV["SIMPLE_APP_SIGNATURE"]
    I18n.t("sms.request_otp", otp: user.otp, app_signature: app_signature)
  end
end

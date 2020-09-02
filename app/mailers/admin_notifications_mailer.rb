class AdminNotificationsMailer < ApplicationMailer
  def send_otp(data)
    @data = data
    mail to: 'maksym@appdev.academy', subject: 'OTP sent!'
  end
end

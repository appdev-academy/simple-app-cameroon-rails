namespace :db do
  desc 'Generate some fake data for a seed user roles;Example: rake "db:seed_users_data'
  task seed_users_data: :environment do
    abort "Can't run this task in env:#{ENV['SIMPLE_SERVER_ENV']}!" if ENV['SIMPLE_SERVER_ENV'] == 'production'

    if ENV['SEED_GENERATED_ACTIVE_USER_ROLE'].blank? || ENV['SEED_GENERATED_INACTIVE_USER_ROLE'].blank?
      abort "Can't proceed! \n" \
      "Set configs for: ENV['SEED_GENERATED_ACTIVE_USER_ROLE'] and ENV['SEED_GENERATED_INACTIVE_USER_ROLE'] " \
      "before running this task. \n" \
      "Make sure there are some users created with those two roles; see db:seed."
    end


    User.where(id: ["bfe738a4-c28f-4cf5-aab9-4a435c0205d7", "85eb659d-451a-4155-8c24-59eef8968117", "32ca1761-9120-4171-8ef3-86cdcfab30a1", "ad432df0-d569-4892-b9b8-e0a56327d6a7"])
      .each { |user| SeedUsersDataJob.perform_async(user.id) }
  end

  desc 'Purge all user data; Example: rake "db:purge_users_data'
  task purge_users_data: :environment do
    abort "Can't run this task in #{ENV['SIMPLE_SERVER_ENV']}!'" if ENV['SIMPLE_SERVER_ENV'] == 'production'

    require 'tasks/scripts/purge_users_data'
    PurgeUsersData.perform
  end
end

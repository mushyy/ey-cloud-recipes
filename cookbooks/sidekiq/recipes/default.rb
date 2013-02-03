#
# Cookbook Name:: sidekiq
# Recipe:: default
#

if named_util_or_app_server?(node[:sidekiq][:utility_name]) 
  # report to dashboard
  ey_cloud_report "sidekiq" do
    message "Setting up sidekiq"
  end

  # bin script
  template "/engineyard/bin/sidekiq" do
    mode 0755
    source "sidekiq.erb" 
    backup false
  end
  
  # loop through applications
  node[:applications].each do |app_name, _|
    # reload monit
    execute "restart-sidekiq-for-#{app_name}" do
      command "monit reload && sleep 1 && monit restart all -g #{app_name}_sidekiq"
      action :nothing
    end
    
    # monit
    template "/etc/monit.d/sidekiq_#{app_name}.monitrc" do 
      mode 0644 
      source "sidekiq.monitrc.erb" 
      backup false
      variables({ 
        :app_name => app_name, 
        :workers => node[:sidekiq][:workers],
        :rails_env => node[:environment][:framework_env]
      })
      notifies :run, resources(:execute => "restart-sidekiq-for-#{app_name}"), :immediately
    end

    # yml files
    node[:sidekiq][:workers].times do |count|
      template "/data/#{app_name}/shared/config/sidekiq_#{count}.yml" do
        owner node[:owner_name]
        group node[:owner_name]
        mode 0644
        source "sidekiq.yml.erb"
        backup false
        variables(node[:sidekiq])
        notifies :run, resources(:execute => "restart-sidekiq-for-#{app_name}"), :immediately
      end
    end
  end 
end
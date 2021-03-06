#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
#
# All Rights Reserved
#

# install

installer_file = node['private-chef']['installer_file']
installer_name = ::File.basename(installer_file)
installer_path = "#{Chef::Config[:file_cache_path]}/#{installer_name}"

if ::URI.parse(installer_file).absolute?
  remote_file installer_path do
    source installer_file
    checksum node['private-chef']['installer_checksum']
    action :create
  end
else
  installer_path = installer_file
end

if PackageHelper.private_chef_installed_version > PackageHelper.pc_version(installer_name)
  log "Installed package #{PackageHelper.private_chef_installed} is newer than installer #{installer_name}"
else
  package installer_name do
    source installer_path
    provider Chef::Provider::Package::Dpkg if platform_family?('debian')
    action :install
  end

  if PackageHelper.private_chef_installed_version < PackageHelper.pc_version(installer_name) &&
    PackageHelper.private_chef_installed_version != '0.0.0'
    file '/tmp/private-chef-perform-upgrade' do
      action :create
      owner 'root'
      group 'root'
      mode '0644'
      content "Running upgrade of #{installer_name} at #{Time.now}"
    end
  end
end

# configure
directory "/etc/opscode" do
  owner "root"
  group "root"
  recursive true
  action :create
end

template "/etc/opscode/private-chef.rb" do
  source "private-chef.rb.erb"
  owner "root"
  group "root"
  variables(
    :backends => (node['private-chef']['backends'] || {}),
    :frontends => (node['private-chef']['frontends'] || {}),
    :backend_vip => (node['private-chef']['backend_vip'] || nil)
  )
  action :create
end

# SSH key management for inter-node trust
directory '/root/.ssh' do
  owner 'root'
  group 'root'
  mode '0700'
  action :create
end

file '/root/.ssh/id_rsa' do
  action :create
  owner 'root'
  group 'root'
  mode '0600'
  content node['root_ssh']['privkey']
end

file '/root/.ssh/authorized_keys' do
  action :create
  owner 'root'
  group 'root'
  mode '0600'
  content node['root_ssh']['pubkey']
end

file '/root/.ssh/config' do
  action :create
  owner 'root'
  group 'root'
  mode '0600'
  content "Host *\n  StrictHostKeyChecking no\n"
end

# OC-11490 bug fix
directory '/var/log/opscode/keepalived' do
  owner 'opscode'
  recursive true
  mode "0700"
end

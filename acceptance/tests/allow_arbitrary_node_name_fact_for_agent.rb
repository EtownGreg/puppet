require 'puppet/acceptance/config_utils'
extend Puppet::Acceptance::ConfigUtils

test_name "node_name_fact should be used to determine the node name for puppet agent"

success_message = "node_name_fact setting was correctly used to determine the node name"

testdir = master.tmpdir("nodenamefact")
node_names = []

on agents, facter('kernel') do
  node_names << stdout.chomp
end

node_names.uniq!

authfile = "#{testdir}/auth.conf"
authconf = node_names.map do |node_name|
  %Q[
path /catalog/#{node_name}
auth yes
allow *

path /node/#{node_name}
auth yes
allow *

path /report/#{node_name}
auth yes
allow *
]
end.join("\n")

manifest_file = "#{testdir}/manifest.pp"
manifest = %Q[
  Exec { path => "/usr/bin:/bin" }
  node default {
    notify { "false": }
  }
]
manifest << node_names.map do |node_name|
  %Q[
    node "#{node_name}" {
      notify { "#{success_message}": }
    }
  ]
end.join("\n")

puppetconf_file = "#{testdir}/puppet.conf"
with_these_opts = {
  'master' => {
    'rest_authconfig' => "#{testdir}/auth.conf",
    'node_terminus'   => nil,
    'manifest'        => manifest_file
  }
}

create_remote_file master, authfile, authconf
create_remote_file master, manifest_file, manifest

on master, "chmod 644 #{authfile} #{manifest_file}"
on master, "chmod 777 #{testdir}"

with_puppet_running_on master, with_these_opts, testdir do

  run_agent_on(agents, "--no-daemonize --verbose --onetime --node_name_fact kernel --server #{master}") do
    assert_match(/defined 'message'.*#{success_message}/, stdout)
  end

end

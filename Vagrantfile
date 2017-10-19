Vagrant.configure("2") do |config|
  config.vm.provider "hyperv" do |h|
    h.enable_virtualization_extensions = true
    h.differencing_disk = true
  end

  config.vm.box_check_update = false

  vagrant_password = 'vagrant'

  config.vm.define "dc" do |dc|
    dc.vm.communicator = "winrm"
    dc.vm.box = "windows-2016-datacenter"
    dc.vm.provider "hyperv" do |hyperv|
      hyperv.vmname = "dc"
    end
    config.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "vagrant", smb_password: vagrant_password
  end

  (1..3).each do |index|
    config.vm.define "fileserver-#{index}" do |fileserver|
      fileserver.vm.communicator = "winrm"
      fileserver.vm.box = "windows-2016-datacenter"
      fileserver.vm.provider "hyperv" do |hyperv|
        hyperv.vmname = "fileserver-#{index}"
      end
      config.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "vagrant", smb_password: vagrant_password
    end
  end
end

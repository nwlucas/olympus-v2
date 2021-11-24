merge_how:
- name: list
  settings: [append]
- name: dict
  settings: [no_replace, recurse_list]
runcmd:
- sh -c 'echo "sudo apt autoremove -y" >> /etc/cron.monthly/autoremove'
- chmod +x /etc/cron.monthly/autoremove
- apt autoremove -y
power_state:
  delay: "+1"
  mode: reboot
  message: "Cloud-Init: Reboot"
  timeout: 600

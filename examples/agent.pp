# A SIP server that captures SIP and sends it to a HOMER server elsewhere.
class { 'homer':
  install_agent      => true,
  agent_interface    => 'eth0',
  agent_hep_server   => 'homer.example.com:9060',
  agent_capture_mode => 'SIP',
}

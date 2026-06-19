output "ec2_public_ip" {
  value = aws_instance.prem_analytics_server.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_instance.prem_analytics_server.public_ip}"
}
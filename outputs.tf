output "my-public-ip" {
  value = aws_instance.app_server.public_ip
}

output "my-public-DNS" {
  value = "http://${aws_instance.app_server.public_dns}"
}
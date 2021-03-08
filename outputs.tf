#### loadbalancer outputs.tf ####

output "elb_dns_name" {
  value = "${aws_alb.alb.dns_name}"
}